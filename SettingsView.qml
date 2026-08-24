import QtQuick
import qs.Commons
import qs.Ui

// The calendar's settings page, shown in place of the month grid.
//
// Kept in its own file rather than folded into Panel.qml: the panel is
// already long, and everything here is presentation over values the panel
// owns. This component reads state and emits intent, it never writes
// shell.json itself.
Column {
  id: root

  property color foreground: "white"
  property string fontFamily: ""

  property var calendars: []
  property var hiddenCalendars: []
  property bool showYearProgress: false
  property bool weekStartsMonday: true
  property bool showWorkingLocation: false
  property bool hideDeclined: false
  property int announceLeadMinutes: 15
  property bool agendaView: false
  property int agendaCount: 10

  property string syncedAt: ""
  property string sourceLabel: ""
  property int eventCount: 0
  property string syncState: "missing"
  property string setupCommand: ""
  property bool setupCommandCopied: false

  signal calendarToggled(string calendarId)
  signal yearProgressToggled()
  signal weekStartToggled()
  signal workingLocationToggled()
  signal hideDeclinedToggled()
  signal leadMinutesPicked(int minutes)
  signal agendaViewToggled()
  signal agendaCountPicked(int count)
  signal setupCommandCopyRequested()

  readonly property color muted: Qt.darker(foreground, 1.5)
  readonly property color faint: Qt.darker(foreground, 1.9)

  spacing: Style.space(10)

  component SectionTitle: Text {
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 1
    font.bold: true
  }

  // A row that reads as a switch without pulling in a control library the
  // rest of this plugin does not use.
  component ToggleRow: Rectangle {
    id: toggle

    property string label: ""
    property string hint: ""
    property bool checked: false
    property color swatch: "transparent"

    signal activated()

    width: parent ? parent.width : 0
    height: toggleBody.height + Style.space(6)
    radius: Style.cornerRadius
    color: hovered.hovered
      ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
      : "transparent"

    HoverHandler { id: hovered }
    TapHandler { onTapped: toggle.activated() }

    Row {
      id: toggleBody
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: Style.space(3)
      anchors.rightMargin: Style.space(3)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(14)
        text: toggle.checked ? "✓" : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: toggle.swatch != "transparent"
        width: Style.space(4)
        height: width
        radius: width / 2
        color: toggle.checked ? toggle.swatch : "transparent"
        border.width: Style.spacing.hairline
        border.color: toggle.swatch
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: toggleBody.width - Style.space(26)
        spacing: Style.space(1)

        Text {
          width: parent.width
          text: toggle.label
          color: toggle.checked ? root.foreground : root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          visible: toggle.hint !== ""
          text: toggle.hint
          color: root.faint
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  // One value out of a handful. Generalised from the announce-lead chips
  // rather than added beside them, so the two rows cannot drift apart.
  component ChipRow: Row {
    id: chips

    property var values: []
    property var current: null
    // Off draws the row faded and stops it responding, for a setting that
    // only means something while something else is on.
    property bool live: true
    property var labelFor: function(value) { return String(value) }

    signal picked(var value)

    spacing: Style.space(3)
    opacity: live ? 1.0 : 0.4

    Repeater {
      model: chips.values

      Rectangle {
        required property var modelData

        readonly property bool selected: modelData === chips.current

        width: chipLabel.width + Style.space(8)
        height: chipLabel.height + Style.space(4)
        radius: height / 2
        color: selected
          ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)
          : "transparent"
        border.width: Style.spacing.hairline
        border.color: selected ? root.muted : Qt.darker(root.foreground, 2.4)

        Text {
          id: chipLabel
          anchors.centerIn: parent
          text: chips.labelFor(modelData)
          color: selected ? root.foreground : root.faint
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        TapHandler {
          enabled: chips.live
          onTapped: chips.picked(modelData)
        }
      }
    }
  }

  // ---- Calendars

  SectionTitle { text: qsTr("CALENDARS") }

  Text {
    width: parent.width
    visible: root.calendars.length === 0
    text: qsTr("Nothing synced yet, so there is nothing to choose from.")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Repeater {
    model: root.calendars

    ToggleRow {
      required property var modelData

      label: modelData.name
      swatch: modelData.color
      checked: root.hiddenCalendars.indexOf(modelData.id) === -1
      onActivated: root.calendarToggled(modelData.id)
    }
  }

  // ---- Display

  SectionTitle { text: qsTr("DISPLAY") }

  ToggleRow {
    label: qsTr("Week starts on Monday")
    hint: qsTr("Off starts the week on Sunday")
    checked: root.weekStartsMonday
    onActivated: root.weekStartToggled()
  }

  ToggleRow {
    label: qsTr("Working location events")
    hint: qsTr("Google's work-from-home markers, hidden by default")
    checked: root.showWorkingLocation
    onActivated: root.workingLocationToggled()
  }

  ToggleRow {
    // Every row on this page reads "checked means shown". Phrasing this one as
    // "Hide ..." inverted that and made the page contradict itself.
    label: qsTr("Declined invitations")
    hint: qsTr("Shown struck through when on")
    checked: !root.hideDeclined
    onActivated: root.hideDeclinedToggled()
  }

  ToggleRow {
    label: qsTr("Year and life progress")
    hint: qsTr("The upstream clock's bars, off by default")
    checked: root.showYearProgress
    onActivated: root.yearProgressToggled()
  }

  // ---- Agenda

  SectionTitle { text: qsTr("AGENDA") }

  ToggleRow {
    label: qsTr("Agenda view")
    hint: qsTr("What is coming up, instead of the day you picked")
    checked: root.agendaView
    onActivated: root.agendaViewToggled()
  }

  Text {
    width: parent.width
    text: qsTr("How many events to list. Today is shown in full even when it runs over.")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  ChipRow {
    values: [5, 10, 15, 25]
    current: root.agendaCount
    live: root.agendaView
    onPicked: function(value) { root.agendaCountPicked(value) }
  }

  // ---- Bar

  SectionTitle { text: qsTr("BAR LABEL") }

  Text {
    width: parent.width
    text: qsTr("How early the bar gives up the clock to announce what is next.")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  ChipRow {
    values: [0, 5, 15, 30, 60]
    current: root.announceLeadMinutes
    labelFor: function(value) { return value === 0 ? qsTr("Never") : value + qsTr("min") }
    onPicked: function(value) { root.leadMinutesPicked(value) }
  }

  // ---- Sync status. Read-only on purpose: changing the Google account is an
  //      OAuth browser flow, which belongs to sync/setup and not to a popup
  //      in a status bar. What belongs here is knowing whether it is working.

  SectionTitle { text: qsTr("SYNC") }

  Text {
    width: parent.width
    color: root.syncState === "missing" && syncHover.hovered ? root.foreground : root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap

    HoverHandler {
      id: syncHover
      enabled: root.syncState === "missing"
      cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
      enabled: root.syncState === "missing"
      onTapped: root.setupCommandCopyRequested()
    }

    text: {
      if (root.syncState === "missing") {
        return root.setupCommandCopied
          ? qsTr("Copied. Paste it in a terminal:\n%1").arg(root.setupCommand)
          : qsTr("No calendar connected yet. Click to copy, then run:\n%1").arg(root.setupCommand)
      }
      if (root.syncState === "version") return qsTr("The events file was written by a newer version of this plugin.")

      var line = root.eventCount + qsTr(" events from ") + root.sourceLabel
      if (root.syncState === "stale") {
        return line + qsTr("\nLast sync looks old. Check: journalctl --user -u omarchy-calendar-sync")
      }
      return line + qsTr("\nLast sync ") + root.syncedAt
    }
  }
}
