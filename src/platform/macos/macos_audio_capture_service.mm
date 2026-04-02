#include "platform/macos/macos_audio_capture_service.hpp"

#import <CoreMedia/CoreMedia.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

#include <AudioToolbox/AudioToolbox.h>

#include <QString>

#include <algorithm>
#include <cstddef>
#include <stdexcept>
#include <vector>

QString qstring_from_nsstring(NSString* value) {
    if (value == nil) {
        return {};
    }
    return QString::fromUtf8(value.UTF8String);
}

std::string ns_error_to_string(NSError* error) {
    if (error == nil) {
        return {};
    }
    NSString* description = error.localizedDescription != nil ? error.localizedDescription : @"Unknown macOS error";
    return qstring_from_nsstring(description).toStdString();
}

bool screen_capture_kit_available() {
    if (@available(macOS 13.0, *)) {
        return true;
    }
    return false;
}

std::string timed_out_error(const char* operation) {
    return std::string(operation) + " timed out";
}

@interface ShinsokuMacOSSystemAudioBridge : NSObject <SCStreamOutput, SCStreamDelegate>

- (instancetype)initWithOwner:(ohmytypeless::MacOSAudioCaptureService*)owner
                   sampleRate:(NSInteger)sampleRate
                 channelCount:(NSInteger)channelCount;
- (BOOL)startCapture:(std::string*)errorText API_AVAILABLE(macos(13.0));
- (void)stopCapture:(std::string*)errorText API_AVAILABLE(macos(13.0));

@end

@implementation ShinsokuMacOSSystemAudioBridge {
    ohmytypeless::MacOSAudioCaptureService* _owner;
    NSInteger _sampleRate;
    NSInteger _channelCount;
    dispatch_queue_t _sampleQueue;
    SCStream* _stream;
}

- (instancetype)initWithOwner:(ohmytypeless::MacOSAudioCaptureService*)owner
                   sampleRate:(NSInteger)sampleRate
                 channelCount:(NSInteger)channelCount {
    self = [super init];
    if (self != nil) {
        _owner = owner;
        _sampleRate = sampleRate;
        _channelCount = channelCount;
        _sampleQueue = dispatch_queue_create("shinsoku.macos.system_audio", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)startCapture:(std::string*)errorText {
    if (@available(macOS 13.0, *)) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block SCShareableContent* shareableContent = nil;
        __block NSError* shareableError = nil;
        [SCShareableContent getShareableContentExcludingDesktopWindows:NO
                                                   onScreenWindowsOnly:YES
                                                     completionHandler:^(SCShareableContent* _Nullable content,
                                                                         NSError* _Nullable error) {
            shareableContent = content;
            shareableError = error;
            dispatch_semaphore_signal(semaphore);
        }];

        if (dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 10LL * NSEC_PER_SEC)) != 0) {
            if (errorText != nullptr) {
                *errorText = timed_out_error("Loading macOS shareable content");
            }
            return NO;
        }

        if (shareableError != nil) {
            if (errorText != nullptr) {
                *errorText = ns_error_to_string(shareableError);
            }
            return NO;
        }
        if (shareableContent.displays.count == 0) {
            if (errorText != nullptr) {
                *errorText = "No macOS display is available for system audio capture.";
            }
            return NO;
        }

        SCDisplay* display = shareableContent.displays.firstObject;
        SCContentFilter* filter = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:@[]];
        SCStreamConfiguration* configuration = [[SCStreamConfiguration alloc] init];
        configuration.width = 2;
        configuration.height = 2;
        configuration.minimumFrameInterval = CMTimeMake(1, 5);
        configuration.queueDepth = 3;
        configuration.capturesAudio = YES;
        configuration.sampleRate = _sampleRate;
        configuration.channelCount = _channelCount;
        configuration.excludesCurrentProcessAudio = YES;

        _stream = [[SCStream alloc] initWithFilter:filter configuration:configuration delegate:self];
        if (_stream == nil) {
            if (errorText != nullptr) {
                *errorText = "Failed to create the macOS ScreenCaptureKit stream.";
            }
            return NO;
        }

        NSError* addOutputError = nil;
        if (![_stream addStreamOutput:self type:SCStreamOutputTypeAudio sampleHandlerQueue:_sampleQueue error:&addOutputError]) {
            if (errorText != nullptr) {
                *errorText = ns_error_to_string(addOutputError);
            }
            _stream = nil;
            return NO;
        }

        dispatch_semaphore_t startSemaphore = dispatch_semaphore_create(0);
        __block NSError* startError = nil;
        [_stream startCaptureWithCompletionHandler:^(NSError* _Nullable error) {
            startError = error;
            dispatch_semaphore_signal(startSemaphore);
        }];
        if (dispatch_semaphore_wait(startSemaphore, dispatch_time(DISPATCH_TIME_NOW, 10LL * NSEC_PER_SEC)) != 0) {
            if (errorText != nullptr) {
                *errorText = timed_out_error("Starting macOS system audio capture");
            }
            return NO;
        }
        if (startError != nil) {
            if (errorText != nullptr) {
                *errorText = ns_error_to_string(startError);
            }
            return NO;
        }
        return YES;
    }

    if (errorText != nullptr) {
        *errorText = "System audio capture requires macOS 13.0 or newer.";
    }
    return NO;
}

- (void)stopCapture:(std::string*)errorText {
    if (@available(macOS 13.0, *)) {
        if (_stream == nil) {
            return;
        }

        dispatch_semaphore_t stopSemaphore = dispatch_semaphore_create(0);
        __block NSError* stopError = nil;
        [_stream stopCaptureWithCompletionHandler:^(NSError* _Nullable error) {
            stopError = error;
            dispatch_semaphore_signal(stopSemaphore);
        }];
        if (dispatch_semaphore_wait(stopSemaphore, dispatch_time(DISPATCH_TIME_NOW, 5LL * NSEC_PER_SEC)) != 0) {
            if (errorText != nullptr) {
                *errorText = timed_out_error("Stopping macOS system audio capture");
            }
        } else if (stopError != nil && errorText != nullptr) {
            *errorText = ns_error_to_string(stopError);
        }

        NSError* removeError = nil;
        [_stream removeStreamOutput:self type:SCStreamOutputTypeAudio error:&removeError];
        _stream = nil;
    }
}

- (void)stream:(SCStream*)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if (type != SCStreamOutputTypeAudio || sampleBuffer == nullptr || !CMSampleBufferIsValid(sampleBuffer) ||
        !CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }

    CMAudioFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
    const AudioStreamBasicDescription* asbd = format != nullptr ? CMAudioFormatDescriptionGetStreamBasicDescription(format) : nullptr;
    if (asbd == nullptr || asbd->mChannelsPerFrame == 0) {
        return;
    }

    const CMItemCount frameCount = CMSampleBufferGetNumSamples(sampleBuffer);
    if (frameCount <= 0) {
        return;
    }

    const UInt32 sourceChannelCount = static_cast<UInt32>(asbd->mChannelsPerFrame);
    const std::size_t bufferListSize =
        offsetof(AudioBufferList, mBuffers) + sizeof(AudioBuffer) * std::max<UInt32>(1, sourceChannelCount);
    std::vector<std::byte> bufferListStorage(bufferListSize);
    auto* bufferList = reinterpret_cast<AudioBufferList*>(bufferListStorage.data());

    CMBlockBufferRef blockBuffer = nullptr;
    const OSStatus status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
        sampleBuffer,
        nullptr,
        bufferList,
        static_cast<size_t>(bufferListSize),
        kCFAllocatorDefault,
        kCFAllocatorDefault,
        kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
        &blockBuffer);
    if (status != noErr) {
        return;
    }

    std::vector<float> samples(static_cast<std::size_t>(frameCount) * static_cast<std::size_t>(_channelCount));
    const bool isFloat = (asbd->mFormatFlags & kAudioFormatFlagIsFloat) != 0;
    const bool isSignedInteger = (asbd->mFormatFlags & kAudioFormatFlagIsSignedInteger) != 0;
    const bool nonInterleaved = (asbd->mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;

    if (isFloat && asbd->mBitsPerChannel == 32) {
        if (nonInterleaved) {
            for (CMItemCount frame = 0; frame < frameCount; ++frame) {
                for (NSInteger channel = 0; channel < _channelCount; ++channel) {
                    if (_channelCount == 1) {
                        float mixed = 0.0f;
                        for (UInt32 sourceChannel = 0; sourceChannel < bufferList->mNumberBuffers; ++sourceChannel) {
                            const auto* channelData = static_cast<const float*>(bufferList->mBuffers[sourceChannel].mData);
                            mixed += channelData[frame];
                        }
                        samples[static_cast<std::size_t>(frame)] =
                            mixed / static_cast<float>(std::max<UInt32>(1, bufferList->mNumberBuffers));
                        break;
                    }
                    if (static_cast<UInt32>(channel) < bufferList->mNumberBuffers) {
                        const auto* channelData = static_cast<const float*>(bufferList->mBuffers[channel].mData);
                        samples[static_cast<std::size_t>(frame) * static_cast<std::size_t>(_channelCount) +
                                static_cast<std::size_t>(channel)] = channelData[frame];
                    }
                }
            }
        } else {
            const auto* input = static_cast<const float*>(bufferList->mBuffers[0].mData);
            const std::size_t sourceSamples =
                static_cast<std::size_t>(frameCount) * static_cast<std::size_t>(sourceChannelCount);
            if (_channelCount == static_cast<NSInteger>(sourceChannelCount)) {
                samples.assign(input, input + sourceSamples);
            } else if (_channelCount == 1) {
                for (CMItemCount frame = 0; frame < frameCount; ++frame) {
                    float mixed = 0.0f;
                    for (UInt32 channel = 0; channel < sourceChannelCount; ++channel) {
                        mixed += input[static_cast<std::size_t>(frame) * sourceChannelCount + channel];
                    }
                    samples[static_cast<std::size_t>(frame)] = mixed / static_cast<float>(sourceChannelCount);
                }
            } else {
                const std::size_t targetSamples =
                    static_cast<std::size_t>(frameCount) * static_cast<std::size_t>(_channelCount);
                samples.resize(targetSamples);
                const std::size_t copyChannels = std::min<std::size_t>(sourceChannelCount, _channelCount);
                for (CMItemCount frame = 0; frame < frameCount; ++frame) {
                    for (std::size_t channel = 0; channel < copyChannels; ++channel) {
                        samples[static_cast<std::size_t>(frame) * static_cast<std::size_t>(_channelCount) + channel] =
                            input[static_cast<std::size_t>(frame) * static_cast<std::size_t>(sourceChannelCount) + channel];
                    }
                }
            }
        }
    } else if (isSignedInteger && asbd->mBitsPerChannel == 16 && !nonInterleaved) {
        const auto* input = static_cast<const std::int16_t*>(bufferList->mBuffers[0].mData);
        if (_channelCount == 1) {
            for (CMItemCount frame = 0; frame < frameCount; ++frame) {
                float mixed = 0.0f;
                for (UInt32 channel = 0; channel < sourceChannelCount; ++channel) {
                    mixed += static_cast<float>(input[static_cast<std::size_t>(frame) * sourceChannelCount + channel]) / 32768.0f;
                }
                samples[static_cast<std::size_t>(frame)] = mixed / static_cast<float>(sourceChannelCount);
            }
        } else {
            for (CMItemCount frame = 0; frame < frameCount; ++frame) {
                for (NSInteger channel = 0; channel < _channelCount && channel < static_cast<NSInteger>(sourceChannelCount); ++channel) {
                    samples[static_cast<std::size_t>(frame) * static_cast<std::size_t>(_channelCount) + static_cast<std::size_t>(channel)] =
                        static_cast<float>(input[static_cast<std::size_t>(frame) * static_cast<std::size_t>(sourceChannelCount) +
                                                 static_cast<std::size_t>(channel)]) /
                        32768.0f;
                }
            }
        }
    } else {
        CFRelease(blockBuffer);
        return;
    }

    CFRelease(blockBuffer);
    if (_owner != nullptr && !samples.empty()) {
        _owner->append_system_audio_samples(samples.data(), samples.size());
    }
}

- (void)stream:(SCStream*)stream didStopWithError:(NSError*)error {
    (void)stream;
    if (_owner != nullptr && error != nil) {
        _owner->fail_system_audio_capture(ns_error_to_string(error));
    }
}

@end

namespace ohmytypeless {

MacOSAudioCaptureService::MacOSAudioCaptureService() = default;

MacOSAudioCaptureService::~MacOSAudioCaptureService() {
    try {
        stop();
    } catch (...) {
    }
}

bool MacOSAudioCaptureService::supports_capture_mode(AudioCaptureMode capture_mode) const {
    if (capture_mode == AudioCaptureMode::Microphone) {
        return true;
    }
    return screen_capture_kit_available();
}

void MacOSAudioCaptureService::start(std::uint32_t sample_rate,
                                     std::uint32_t channels,
                                     const std::string& device_id,
                                     AudioCaptureMode capture_mode) {
    if (capture_mode == AudioCaptureMode::Microphone) {
        active_mode_ = AudioCaptureMode::Microphone;
        microphone_delegate_.start(sample_rate, channels, device_id, capture_mode);
        recording_.store(true);
        return;
    }

    if (!supports_capture_mode(AudioCaptureMode::SystemLoopback)) {
        throw std::runtime_error("System audio capture requires macOS 13.0 or newer.");
    }

    {
        std::scoped_lock lock(mutex_);
        if (recording_.load()) {
            return;
        }
        samples_.clear();
        pending_samples_.clear();
        capture_error_.reset();
        active_mode_ = AudioCaptureMode::SystemLoopback;
    }

    std::string error_text;
    system_bridge_ = [[ShinsokuMacOSSystemAudioBridge alloc] initWithOwner:this
                                                                sampleRate:static_cast<NSInteger>(sample_rate)
                                                              channelCount:static_cast<NSInteger>(channels)];
    if (system_bridge_ == nullptr || ![system_bridge_ startCapture:&error_text]) {
        system_bridge_ = nil;
        active_mode_ = AudioCaptureMode::Microphone;
        if (error_text.empty()) {
            error_text = "Failed to start macOS system audio capture.";
        }
        throw std::runtime_error(error_text);
    }

    recording_.store(true);
}

std::vector<float> MacOSAudioCaptureService::stop() {
    if (active_mode_ == AudioCaptureMode::Microphone) {
        recording_.store(false);
        return microphone_delegate_.stop();
    }

    std::vector<float> samples;
    {
        std::scoped_lock lock(mutex_);
        samples = std::move(samples_);
        samples_.clear();
        pending_samples_.clear();
    }

    std::string stop_error;
    if (system_bridge_ != nullptr) {
        [system_bridge_ stopCapture:&stop_error];
        system_bridge_ = nil;
    }

    recording_.store(false);
    active_mode_ = AudioCaptureMode::Microphone;

    if (!stop_error.empty() && samples.empty()) {
        throw std::runtime_error(stop_error);
    }
    if (const auto error = take_capture_error(); error.has_value() && samples.empty()) {
        throw std::runtime_error(*error);
    }
    return samples;
}

std::vector<float> MacOSAudioCaptureService::take_pending_samples() {
    if (active_mode_ == AudioCaptureMode::Microphone) {
        return microphone_delegate_.take_pending_samples();
    }

    if (const auto error = take_capture_error(); error.has_value()) {
        throw std::runtime_error(*error);
    }

    std::scoped_lock lock(mutex_);
    std::vector<float> chunk = std::move(pending_samples_);
    pending_samples_.clear();
    return chunk;
}

bool MacOSAudioCaptureService::is_recording() const {
    if (active_mode_ == AudioCaptureMode::Microphone) {
        return microphone_delegate_.is_recording();
    }
    return recording_.load();
}

std::vector<AudioInputDevice> MacOSAudioCaptureService::list_input_devices() const {
    return microphone_delegate_.list_input_devices();
}

void MacOSAudioCaptureService::append_system_audio_samples(const float* samples, std::size_t sample_count) {
    if (samples == nullptr || sample_count == 0) {
        return;
    }

    std::scoped_lock lock(mutex_);
    if (!recording_.load() || active_mode_ != AudioCaptureMode::SystemLoopback) {
        return;
    }
    samples_.insert(samples_.end(), samples, samples + sample_count);
    pending_samples_.insert(pending_samples_.end(), samples, samples + sample_count);
}

void MacOSAudioCaptureService::fail_system_audio_capture(const std::string& error_text) {
    std::scoped_lock lock(mutex_);
    capture_error_ = error_text;
    recording_.store(false);
}

std::optional<std::string> MacOSAudioCaptureService::take_capture_error() {
    std::scoped_lock lock(mutex_);
    if (!capture_error_.has_value()) {
        return std::nullopt;
    }
    auto error = std::move(capture_error_);
    capture_error_.reset();
    return error;
}

}  // namespace ohmytypeless
