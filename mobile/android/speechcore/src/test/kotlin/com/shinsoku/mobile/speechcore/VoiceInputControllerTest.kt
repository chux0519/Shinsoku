package com.shinsoku.mobile.speechcore

import kotlin.test.Test
import kotlin.test.assertEquals

class VoiceInputControllerTest {
    @Test
    fun `mic tap starts listening and final result commits trailing space`() {
        val engine = FakeVoiceInputEngine()
        val observer = RecordingObserver()
        val controller = VoiceInputController(
            engine = engine,
            configStore = FakeConfigStore(),
            observer = observer,
            postProcessor = ImmediatePostProcessor(),
        )

        controller.onMicTapped()
        engine.dispatchReady()
        engine.dispatchFinal("hello world")

        assertEquals(
            listOf(
                VoiceInputUiState.Listening(),
                VoiceInputUiState.Listening(),
                VoiceInputUiState.Processing,
                VoiceInputUiState.Idle,
            ),
            observer.states,
        )
        assertEquals(listOf(VoiceInputCommit("hello world ")), observer.commits)
    }

    @Test
    fun `partial results update listening state`() {
        val engine = FakeVoiceInputEngine()
        val observer = RecordingObserver()
        val controller = VoiceInputController(
            engine = engine,
            configStore = FakeConfigStore(),
            observer = observer,
            postProcessor = ImmediatePostProcessor(),
        )

        controller.onMicTapped()
        engine.dispatchPartial("partial text")

        assertEquals(
            VoiceInputUiState.Listening(partialTranscript = "partial text"),
            observer.states.last(),
        )
    }

    @Test
    fun `empty final result surfaces error`() {
        val engine = FakeVoiceInputEngine()
        val observer = RecordingObserver()
        val controller = VoiceInputController(
            engine = engine,
            configStore = FakeConfigStore(),
            observer = observer,
            postProcessor = ImmediatePostProcessor(),
        )

        controller.onMicTapped()
        engine.dispatchFinal("   ")

        assertEquals(VoiceInputUiState.Error("No speech recognized."), observer.states.last())
        assertEquals(emptyList(), observer.commits)
    }

    @Test
    fun `manual commit mode keeps transcript pending until confirmed`() {
        val engine = FakeVoiceInputEngine()
        val observer = RecordingObserver()
        val controller = VoiceInputController(
            engine = engine,
            configStore = object : VoiceInputConfigStore {
                override fun loadProfile(): VoiceInputProfile = VoiceInputProfile(
                    autoCommit = false,
                    commitSuffixMode = CommitSuffixMode.Newline,
                )
            },
            observer = observer,
            postProcessor = ImmediatePostProcessor(),
        )

        controller.onMicTapped()
        engine.dispatchFinal("hello world")

        assertEquals(
            VoiceInputUiState.PendingCommit("hello world\n"),
            observer.states.last(),
        )
        assertEquals(emptyList(), observer.commits)

        controller.commitPending()

        assertEquals(listOf(VoiceInputCommit("hello world\n")), observer.commits)
        assertEquals(VoiceInputUiState.Idle, observer.states.last())
    }

    private class FakeConfigStore : VoiceInputConfigStore {
        override fun loadProfile(): VoiceInputProfile = VoiceInputProfile(
            autoCommit = true,
            commitSuffixMode = CommitSuffixMode.Space,
        )
    }

    private class RecordingObserver : VoiceInputControllerObserver {
        val states = mutableListOf<VoiceInputUiState>()
        val commits = mutableListOf<VoiceInputCommit>()

        override fun onStateChanged(state: VoiceInputUiState) {
            states += state
        }

        override fun onCommitRequested(commit: VoiceInputCommit) {
            commits += commit
        }
    }

    private class FakeVoiceInputEngine : VoiceInputEngine {
        private var listener: VoiceInputEngine.Listener? = null

        override fun start(profile: VoiceInputProfile, listener: VoiceInputEngine.Listener) {
            this.listener = listener
        }

        override fun stop() = Unit
        override fun cancel() = Unit
        override fun destroy() = Unit

        fun dispatchReady() {
            listener?.onReady()
        }

        fun dispatchPartial(text: String) {
            listener?.onPartialResult(text)
        }

        fun dispatchFinal(text: String) {
            listener?.onFinalResult(text)
        }
    }

    private class ImmediatePostProcessor : VoiceTranscriptPostProcessor {
        override fun process(
            rawText: String,
            profile: VoiceInputProfile,
            callback: VoiceTranscriptPostProcessorCallback,
        ) {
            callback.onSuccess(rawText)
        }
    }
}
