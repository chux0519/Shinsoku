#include "platform/wayland/qwayland_layer_surface.hpp"

#include "platform/wayland/qwayland_layer_shell_integration.hpp"

#include <QtWaylandClient/private/qwaylandscreen_p.h>
#include <QtWaylandClient/private/qwaylandsurface_p.h>
#include <QtWaylandClient/private/qwaylandwindow_p.h>

namespace ohmytypeless {

QWaylandLayerSurface::QWaylandLayerSurface(QWaylandLayerShellIntegration* shell,
                                           QtWaylandClient::QWaylandWindow* window,
                                           std::uint32_t layer,
                                           std::uint32_t anchors,
                                           QMargins margins,
                                           int exclusive_zone,
                                           KeyboardInteractivity keyboard_interactivity,
                                           QString scope,
                                           QSize desired_size)
    : QtWaylandClient::QWaylandShellSurface(window),
      shell_(shell),
      window_(window),
      margins_(margins),
      desired_size_(std::move(desired_size)) {
    wl_output* output = nullptr;
    if (QScreen* desired_screen = window->window()->screen(); desired_screen != nullptr) {
        if (auto* wayland_screen = dynamic_cast<QtWaylandClient::QWaylandScreen*>(desired_screen->handle());
            wayland_screen != nullptr) {
            output = wayland_screen->output();
        }
    }

    init(shell->get_layer_surface(window->waylandSurface()->object(), output, layer, scope));
    set_anchor(anchors);
    set_exclusive_zone(exclusive_zone);
    set_margin(margins.top(), margins.right(), margins.bottom(), margins.left());
    set_keyboard_interactivity(keyboard_interactivity);
    set_desired_size(desired_size_);
    window->commit();
}

QWaylandLayerSurface::~QWaylandLayerSurface() {
    destroy();
}

bool QWaylandLayerSurface::isExposed() const {
    return configured_;
}

void QWaylandLayerSurface::applyConfigure() {
    const QSize applied_size = pending_size_.isValid() && !pending_size_.isEmpty() ? pending_size_ : desired_size_;
    window()->resizeFromApplyConfigure(applied_size);
}

void QWaylandLayerSurface::setWindowSize(const QSize& size) {
    if (desired_size_.isEmpty()) {
        set_desired_size(size);
    }
}

void QWaylandLayerSurface::set_desired_geometry(QMargins margins, QSize desired_size) {
    margins_ = margins;
    desired_size_ = std::move(desired_size);
    set_margin(margins_.top(), margins_.right(), margins_.bottom(), margins_.left());
    set_desired_size(desired_size_);
    if (window_ != nullptr) {
        window_->commit();
    }
}

void QWaylandLayerSurface::zwlr_layer_surface_v1_configure(uint32_t serial, uint32_t width, uint32_t height) {
    ack_configure(serial);
    pending_size_ = QSize(static_cast<int>(width), static_cast<int>(height));

    if (!configured_) {
        configured_ = true;
        applyConfigure();
        send_expose();
    } else {
        window()->applyConfigureWhenPossible();
    }
}

void QWaylandLayerSurface::zwlr_layer_surface_v1_closed() {
    window()->window()->close();
}

void QWaylandLayerSurface::send_expose() {
    window()->updateExposure();
}

void QWaylandLayerSurface::set_desired_size(const QSize& size) {
    QSize effective_size = size;
    if (effective_size.width() < 0) {
        effective_size.setWidth(0);
    }
    if (effective_size.height() < 0) {
        effective_size.setHeight(0);
    }
    set_size(static_cast<uint32_t>(effective_size.width()), static_cast<uint32_t>(effective_size.height()));
}

}  // namespace ohmytypeless
