#include "platform/wayland/qwayland_layer_shell_integration.hpp"

#include "platform/wayland/qwayland_layer_surface.hpp"

#include <utility>

namespace ohmytypeless {

struct QWaylandLayerShellIntegration::PendingSurfaceConfiguration {
    std::uint32_t layer = QWaylandLayerSurface::LayerOverlay;
    std::uint32_t anchors = QWaylandLayerSurface::AnchorLeft | QWaylandLayerSurface::AnchorRight |
                            QWaylandLayerSurface::AnchorBottom;
    QMargins margins;
    int exclusive_zone = -1;
    QWaylandLayerSurface::KeyboardInteractivity keyboard_interactivity = QWaylandLayerSurface::KeyboardInteractivityNone;
    QString scope = QStringLiteral("shinsoku-hud");
    QSize desired_size;
    QPointer<QScreen> target_screen;
};

QWaylandLayerShellIntegration::QWaylandLayerShellIntegration()
    : QtWaylandClient::QWaylandShellIntegrationTemplate<QWaylandLayerShellIntegration>(5),
      pending_surface_configuration_(std::make_unique<PendingSurfaceConfiguration>()) {}

QWaylandLayerShellIntegration::~QWaylandLayerShellIntegration() {
    if (object() != nullptr && zwlr_layer_shell_v1_get_version(object()) >= ZWLR_LAYER_SHELL_V1_DESTROY_SINCE_VERSION) {
        zwlr_layer_shell_v1_destroy(object());
    }
}

QtWaylandClient::QWaylandShellSurface* QWaylandLayerShellIntegration::createShellSurface(
    QtWaylandClient::QWaylandWindow* window) {
    return new QWaylandLayerSurface(this,
                                    window,
                                    pending_surface_configuration_->layer,
                                    pending_surface_configuration_->anchors,
                                    pending_surface_configuration_->margins,
                                    pending_surface_configuration_->exclusive_zone,
                                    pending_surface_configuration_->keyboard_interactivity,
                                    pending_surface_configuration_->scope,
                                    pending_surface_configuration_->desired_size,
                                    pending_surface_configuration_->target_screen);
}

void QWaylandLayerShellIntegration::set_pending_surface_configuration(
    std::uint32_t layer,
    std::uint32_t anchors,
    QMargins margins,
    int exclusive_zone,
    QWaylandLayerSurface::KeyboardInteractivity keyboard_interactivity,
    QString scope,
    QSize desired_size,
    QScreen* target_screen) {
    pending_surface_configuration_->layer = layer;
    pending_surface_configuration_->anchors = anchors;
    pending_surface_configuration_->margins = margins;
    pending_surface_configuration_->exclusive_zone = exclusive_zone;
    pending_surface_configuration_->keyboard_interactivity = keyboard_interactivity;
    pending_surface_configuration_->scope = std::move(scope);
    pending_surface_configuration_->desired_size = std::move(desired_size);
    pending_surface_configuration_->target_screen = target_screen;
}

}  // namespace ohmytypeless
