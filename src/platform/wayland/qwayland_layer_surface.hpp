#pragma once

#include <QtWaylandClient/private/qwaylandshellsurface_p.h>

#include "qwayland-wlr-layer-shell-unstable-v1.h"

#include <QMargins>
#include <QString>

namespace QtWaylandClient {
class QWaylandWindow;
}

namespace ohmytypeless {

class QWaylandLayerShellIntegration;

class QWaylandLayerSurface final : public QtWaylandClient::QWaylandShellSurface, public QtWayland::zwlr_layer_surface_v1 {
    Q_OBJECT
public:
    enum Anchor : std::uint32_t {
        AnchorNone = 0,
        AnchorTop = 1,
        AnchorBottom = 2,
        AnchorLeft = 4,
        AnchorRight = 8,
    };

    enum Layer : std::uint32_t {
        LayerBackground = 0,
        LayerBottom = 1,
        LayerTop = 2,
        LayerOverlay = 3,
    };

    enum KeyboardInteractivity : std::uint32_t {
        KeyboardInteractivityNone = 0,
        KeyboardInteractivityExclusive = 1,
        KeyboardInteractivityOnDemand = 2,
    };

    QWaylandLayerSurface(QWaylandLayerShellIntegration* shell,
                         QtWaylandClient::QWaylandWindow* window,
                         std::uint32_t layer,
                         std::uint32_t anchors,
                         QMargins margins,
                         int exclusive_zone,
                         KeyboardInteractivity keyboard_interactivity,
                         QString scope,
                         QSize desired_size);
    ~QWaylandLayerSurface() override;

    bool isExposed() const override;
    void applyConfigure() override;
    void setWindowSize(const QSize& size) override;
    void set_desired_geometry(QMargins margins, QSize desired_size);

private:
    void zwlr_layer_surface_v1_configure(uint32_t serial, uint32_t width, uint32_t height) override;
    void zwlr_layer_surface_v1_closed() override;
    void send_expose();
    void set_desired_size(const QSize& size);

    QWaylandLayerShellIntegration* shell_ = nullptr;
    QtWaylandClient::QWaylandWindow* window_ = nullptr;
    QMargins margins_;
    QSize pending_size_;
    QSize desired_size_;
    bool configured_ = false;
};

}  // namespace ohmytypeless
