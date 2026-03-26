#pragma once

#include <QtWaylandClient/private/qwaylandshellintegration_p.h>

#include "qwayland-wlr-layer-shell-unstable-v1.h"

#include <QMargins>
#include <QPointer>
#include <QScreen>
#include <QSize>
#include <QString>

#include <cstdint>
#include <memory>

#include "platform/wayland/qwayland_layer_surface.hpp"

namespace ohmytypeless {

class QWaylandLayerShellIntegration final
    : public QtWaylandClient::QWaylandShellIntegrationTemplate<QWaylandLayerShellIntegration>,
      public QtWayland::zwlr_layer_shell_v1 {
public:
    QWaylandLayerShellIntegration();
    ~QWaylandLayerShellIntegration() override;

    QtWaylandClient::QWaylandShellSurface* createShellSurface(QtWaylandClient::QWaylandWindow* window) override;

    void set_pending_surface_configuration(std::uint32_t layer,
                                           std::uint32_t anchors,
                                           QMargins margins,
                                           int exclusive_zone,
                                           QWaylandLayerSurface::KeyboardInteractivity keyboard_interactivity,
                                           QString scope,
                                           QSize desired_size,
                                           QScreen* target_screen);

private:
    struct PendingSurfaceConfiguration;
    std::unique_ptr<PendingSurfaceConfiguration> pending_surface_configuration_;
};

}  // namespace ohmytypeless
