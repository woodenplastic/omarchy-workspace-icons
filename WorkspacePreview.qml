import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons
import qs.Ui

// The hover preview: a miniature of the workspace's monitor over its
// wallpaper, each window a capture of the window itself at its place. The
// panel (Workspaces.qml) decides what to show; this draws it.
Item {
  id: root

  required property var panel
  property Item fallbackAnchor: null
  readonly property bool containsMouse: previewCard.containsMouse
  readonly property alias card: previewCard

  // The preview is passive like a tooltip: it must not take the bar's popout
  // slot, which would close whatever panel is open, so the card gets a bar
  // that only tells it where the bar sits.
  QtObject {
    id: previewBar
    readonly property string position: root.panel.bar ? root.panel.bar.position : "top"
    readonly property var activePopout: null
    function requestPopout(owner) {}
    function releasePopout(owner) {}
  }

  // Header line plus footer line plus the gaps around the miniature.
  readonly property real headerHeight: titleMetrics.height
  readonly property real captionHeight: headerHeight + captionMetrics.height + Style.space(10) * 2

  TextMetrics {
    id: titleMetrics
    font.family: root.panel.panelFont
    font.pixelSize: Style.font.body * 1.15
    text: "Workspace"
  }

  TextMetrics {
    id: captionMetrics
    font.family: root.panel.panelFont
    font.pixelSize: Style.font.bodySmall
    text: "Workspace"
  }

  PopupCard {
    id: previewCard
    anchorItem: root.panel.previewAnchor || root.fallbackAnchor
    bar: previewBar
    triggerMode: "hover"
    open: root.panel.previewOpen
    contentWidth: root.panel.previewSize.width + previewCard.padding * 2 + Border.left(previewCard.borderSpec) + Border.right(previewCard.borderSpec)
    contentHeight: root.panel.previewSize.height + root.captionHeight + previewCard.verticalContentInset
    onVisibleChanged: if (!visible) root.panel.previewClosed()
    onContainsMouseChanged: root.panel.previewCardHovered(containsMouse)

    // The captures exist only while the card is on screen: kept alive while
    // hidden they hold compositor resources and can lose their context
    // across suspend.
    Loader {
      anchors.fill: parent
      active: previewCard.visible
      sourceComponent: Column {
        spacing: Style.space(10)

        // "Workspace 2" on the left, "2 WINDOWS" on the right.
        Item {
          width: root.panel.previewSize.width
          height: root.headerHeight

          Text {
            anchors.left: parent.left
            anchors.right: countText.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.panel.previewTitle
            color: root.panel.panelForeground
            elide: Text.ElideRight
            font.family: root.panel.panelFont
            font.pixelSize: Style.font.body * 1.15
            font.bold: true
          }

          Text {
            id: countText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.panel.previewCount.toUpperCase()
            color: root.panel.panelForeground
            opacity: 0.6
            font.family: root.panel.panelFont
            font.pixelSize: Style.font.bodySmall
            font.letterSpacing: 1.5
          }
        }

        ClippingRectangle {
          width: root.panel.previewSize.width
          height: root.panel.previewSize.height
          radius: Style.cornerRadius > 0 ? Math.max(2, Style.space(6)) : 0
          color: "transparent"
          border.width: 1
          border.color: Qt.rgba(root.panel.panelForeground.r, root.panel.panelForeground.g, root.panel.panelForeground.b, 0.12)

          Image {
            anchors.fill: parent
            visible: root.panel.previewWallpaper !== ""
            source: root.panel.previewWallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: Math.round(width * Screen.devicePixelRatio)
            opacity: 0.85
          }

          Repeater {
            model: root.panel.previewWindows
            delegate: previewWindow
          }
        }

        Text {
          width: root.panel.previewSize.width
          height: captionMetrics.height
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: root.panel.previewCaption
          color: root.panel.panelForeground
          opacity: 0.6
          elide: Text.ElideRight
          font.family: root.panel.panelFont
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }

  Component {
    id: previewWindow

    Rectangle {
      id: frame
      required property var modelData
      readonly property bool highlighted: root.panel.previewHighlight.indexOf(modelData.address) !== -1
      x: modelData.x
      y: modelData.y
      width: modelData.width
      height: modelData.height
      radius: Style.cornerRadius > 0 ? Math.max(2, Style.space(3)) : 0
      color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.1)
      border.width: highlighted ? Math.max(2, Style.space(2)) : 1
      border.color: highlighted ? Color.accent : Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.35)

      ScreencopyView {
        id: capture
        anchors.fill: parent
        anchors.margins: frame.border.width
        captureSource: frame.modelData.toplevel && frame.modelData.toplevel.wayland ? frame.modelData.toplevel.wayland : null
        // Live until the first frame arrives (a single request can miss the
        // last repaint and is not retried), then still unless live previews
        // are on.
        live: root.panel.previewLive || !hasContent
        paintCursor: false
        // Caps the capture buffer near the size it is drawn at.
        constraintSize: Qt.size(width * 2, height * 2)
        opacity: hasContent ? 1 : 0

        Behavior on opacity {
          enabled: root.panel.animations
          NumberAnimation { duration: 120 }
        }
      }

      // The app's icon until its capture arrives, or when there is none.
      Item {
        anchors.centerIn: parent
        visible: !capture.hasContent
        width: Math.min(root.panel.iconSize * 1.6, frame.width * 0.6, frame.height * 0.6)
        height: width

        Image {
          anchors.fill: parent
          visible: String(frame.modelData.icon).indexOf("glyph:") !== 0
          source: visible ? frame.modelData.icon : ""
          fillMode: Image.PreserveAspectFit
          sourceSize.width: Math.round(width * Screen.devicePixelRatio)
          sourceSize.height: Math.round(height * Screen.devicePixelRatio)
          asynchronous: true
        }

        Text {
          anchors.centerIn: parent
          visible: String(frame.modelData.icon).indexOf("glyph:") === 0
          text: visible ? String(frame.modelData.icon).substring(6) : ""
          color: root.panel.panelForeground
          font.family: root.panel.bar ? root.panel.bar.fontFamily : Style.font.family
          font.pixelSize: parent.height
          renderType: Text.NativeRendering
        }
      }

      // The window's app in its corner, so black terminals still say what
      // they are.
      Rectangle {
        visible: capture.hasContent && frame.width > root.panel.iconSize * 2.5 && frame.height > root.panel.iconSize * 2.5
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(5)
        width: root.panel.iconSize + Style.space(6)
        height: width
        radius: Style.cornerRadius > 0 ? Style.space(5) : 0
        color: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.85)

        Image {
          anchors.centerIn: parent
          width: root.panel.iconSize
          height: width
          visible: String(frame.modelData.icon).indexOf("glyph:") !== 0
          source: visible ? frame.modelData.icon : ""
          fillMode: Image.PreserveAspectFit
          sourceSize.width: Math.round(width * Screen.devicePixelRatio)
          sourceSize.height: Math.round(height * Screen.devicePixelRatio)
          asynchronous: true
        }

        Text {
          anchors.centerIn: parent
          visible: String(frame.modelData.icon).indexOf("glyph:") === 0
          text: visible ? String(frame.modelData.icon).substring(6) : ""
          color: root.panel.panelForeground
          font.family: root.panel.bar ? root.panel.bar.fontFamily : Style.font.family
          font.pixelSize: root.panel.iconSize
          renderType: Text.NativeRendering
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.panel.previewWindowHovered(frame.modelData, true)
        onExited: root.panel.previewWindowHovered(frame.modelData, false)
        onClicked: root.panel.previewWindowClicked(frame.modelData)
      }
    }
  }
}
