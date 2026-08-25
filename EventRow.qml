import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// One event, as the calendar panel draws it: colour bar, time, title, and a
// second line for where it is. Lifted out of Panel.qml unchanged so the day
// list and the agenda cannot drift apart.
//
// The hover wash lives on this wrapper, never inside the Row. A
// Row lays out every visible child, so an anchored background
// added as a Row child fights the layout and ejects the content.
Rectangle {
  id: eventRow
  required property var modelData

  // Everything the row used to reach up into the panel for. Both lists that
  // draw a row own their own copy of these.
  property color foreground: "white"
  property string fontFamily: ""
  property real nowMs: 0
  property string todayKey: ""

  // The agenda lists several days at once, so it heads the first row of each
  // with the day it belongs to. The day list, which already has a date above
  // it, leaves this empty and the column disappears.
  property string dayLabel: ""
  property real gutterWidth: 0

  // Already behind you. Not strikeout: that means declined here, and an
  // over-and-done meeting is not a refused one.
  property bool dimmed: false

  // Wide enough for "All day" with breathing room. Timed events stack their
  // end below their start instead of taking title space for a horizontal range.
  readonly property real timeWidth: Style.space(56)

  signal joinRequested(var event)
  signal openRequested(var event)

  readonly property string meetingUrl: Model.meetingUrlFor(modelData)
  readonly property bool declined: Model.isDeclined(modelData)
  // Only around the actual time. A Join button on next week's
  // meeting is noise that dilutes the one that matters.
  readonly property bool joinable: Model.isJoinableNow(modelData, eventRow.nowMs, eventRow.todayKey)
  readonly property string eventUrl: Model.eventUrlFor(modelData)
  readonly property bool openable: eventUrl !== ""

  height: eventBody.height + Style.space(2)
  radius: Style.cornerRadius
  opacity: eventRow.dimmed ? 0.45 : 1.0
  color: eventHover.hovered
    ? Qt.rgba(eventRow.foreground.r, eventRow.foreground.g,
              eventRow.foreground.b, 0.08)
    : "transparent"

  // Only rows that can actually do something respond to a click.
  HoverHandler {
    id: eventHover
    enabled: eventRow.openable || eventRow.joinable
    cursorShape: Qt.PointingHandCursor
  }

  Rectangle {
    id: joinButton
    visible: eventRow.joinable
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: joinLabel.implicitWidth + Style.space(8)
    height: joinLabel.implicitHeight + Style.space(3)
    radius: height / 2
    color: joinHover.hovered
      ? Style.selectedStateColor(eventRow.foreground, Color.accent)
      : "transparent"
    border.width: Style.spacing.hairline
    border.color: joinHover.hovered
      ? "transparent"
      : Qt.darker(eventRow.foreground, 2.0)

    HoverHandler {
      id: joinHover
      cursorShape: Qt.PointingHandCursor
    }

    // Its own handler, declared on the button, so the grab
    // happens here and the row's opener does not also fire.
    TapHandler {
      gesturePolicy: TapHandler.ReleaseWithinBounds
      onTapped: eventRow.joinRequested(eventRow.modelData)
    }

    Text {
      id: joinLabel
      anchors.centerIn: parent
      text: qsTr("Join")
      color: joinHover.hovered ? Color.background : Qt.darker(eventRow.foreground, 1.4)
      font.family: eventRow.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Row {
    id: eventBody
    anchors.left: parent.left
    anchors.right: eventRow.joinable ? joinButton.left : parent.right
    anchors.rightMargin: eventRow.joinable ? Style.space(3) : 0
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(4)

    // Deliberately here and not on the row: this stops at the
    // Join button's left edge, so the two hit areas cannot
    // overlap. Two TapHandlers over one point would both fire
    // and open two tabs.
    TapHandler {
      enabled: eventRow.openable
      onTapped: eventRow.openRequested(eventRow.modelData)
    }

  // A Row lays out no invisible child and inserts no spacing for one, so a
  // row with no day label is laid out exactly as it was before the gutter
  // existed.
  Text {
    visible: eventRow.gutterWidth > 0
    width: eventRow.gutterWidth
    text: eventRow.dayLabel
    color: eventRow.foreground
    font.family: eventRow.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  Rectangle {
    width: Style.space(2)
    height: Math.max(eventTimes.height, eventLines.height)
    radius: width / 2
    color: eventRow.declined
      ? Qt.darker(eventRow.modelData.color, 2.2)
      : eventRow.modelData.color
  }

  Column {
    id: eventTimes
    width: eventRow.timeWidth
    spacing: Style.space(1)

    readonly property var startDate: new Date(eventRow.modelData.start)
    readonly property var endDate: new Date(eventRow.modelData.end)
    readonly property bool hasEnd: !eventRow.modelData.allDay
      && !isNaN(startDate.getTime())
      && !isNaN(endDate.getTime())
      && endDate.getTime() > startDate.getTime()

    Text {
      text: eventRow.modelData.allDay
        ? qsTr("All day")
        : Qt.formatDateTime(eventTimes.startDate, "h:mm AP")
      color: Qt.darker(eventRow.foreground, eventRow.declined ? 2.2 : 1.5)
      font.family: eventRow.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.strikeout: eventRow.declined
    }

    Text {
      visible: eventTimes.hasEnd
      text: visible ? Qt.formatDateTime(eventTimes.endDate, "h:mm AP") : ""
      color: Qt.darker(eventRow.foreground, eventRow.declined ? 2.2 : 1.9)
      font.family: eventRow.fontFamily
      font.pixelSize: Style.font.caption
      font.strikeout: eventRow.declined
    }
  }

  Column {
    id: eventLines
    width: eventBody.width - eventRow.timeWidth - Style.space(10)
      - (eventRow.gutterWidth > 0 ? eventRow.gutterWidth + Style.space(4) : 0)
    spacing: Style.space(1)

    Text {
      width: parent.width
      text: eventRow.modelData.title
      color: eventRow.declined
        ? Qt.darker(eventRow.foreground, 2.0)
        : eventRow.foreground
      font.family: eventRow.fontFamily
      font.pixelSize: Style.font.title
      font.strikeout: eventRow.declined
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: {
        if (eventRow.declined) return qsTr("Declined")
        if (Model.isOutOfOffice(eventRow.modelData)) return qsTr("Out of office")
        return eventRow.modelData.location
      }
      color: Qt.darker(eventRow.foreground, 1.9)
      font.family: eventRow.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }
  }
}
