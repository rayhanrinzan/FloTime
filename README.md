# FloTime

FloTime is a SwiftUI starter app for periodic productivity check-ins. It asks the user what they have been working on, captures a short note plus a 1-10 productivity rating, and visualizes that data across the day.

## Product shape

- Configurable reminder interval, starting at 30 minutes.
- Notification on/off toggle.
- Quiet windows for sleep and work/school.
- Activity log with short text and rating.
- Daily graph and calendar-driven review.
- EventKit integration to mute reminders during selected calendar events.
- Post-event nudge asking whether the user wants to log that event.
- Orange and white theme.

## Open in Xcode

1. Open [FloTime.xcodeproj](./FloTime.xcodeproj) in Xcode.
2. Choose your Apple developer team in the Signing settings.
3. If you want a custom bundle ID, change `com.rayhanrinzan.flotime`.
4. Run the app on an iPhone or simulator with iOS 17 or later.

## Included project pieces

- `FloTime.xcodeproj` with a basic iOS app target.
- `Resources/Info.plist` with the calendar permission string and Google Sign-In placeholders.
- `Resources/Assets.xcassets` for accent color and app icon placeholders.
- Notification routing so tapping a check-in or event follow-up can open a prefilled log sheet.

## How to use the app

1. Open the app and go to `Settings`.
2. Turn on `Enable Check-In Notifications` and choose the reminder interval you want.
3. Adjust `Quiet Windows` for sleep, work, or school hours.
4. Turn on `Use Calendar-Aware Reminders` if you want FloTime to read Apple calendars already on the device and any Google calendars you connect directly.
5. Tap `Sign in with Google` if you want to connect Google Calendar through Google’s official iOS sign-in flow.
6. Choose which calendars should affect quiet-time detection and whether certain events should mute reminders or be suggested as activities afterward.
7. Go back to `Today` and tap `Log Activity` any time you want to add an entry manually.
8. Use the `Calendar` tab to tap a day and see that day’s productivity trend and saved entries.

## What notification taps do

- A normal check-in notification opens a log sheet asking what you have been doing during the last interval.
- A calendar follow-up notification opens a log sheet prefilled with the event title so the user can save it quickly as an activity.

## Google Calendar setup

Before Google sign-in can work in your own build, replace these two placeholder values in `Resources/Info.plist`:

- `GIDClientID`
- the `CFBundleURLSchemes` entry inside `CFBundleURLTypes`

Use the values from an iOS OAuth client in Google Cloud for this app’s bundle ID. The URL scheme should be the reversed client ID that Google gives you.

Apple calendars already added to the iPhone are still available through EventKit, so FloTime can work with both Apple calendars and a direct Google Calendar connection.

## Important implementation note

iOS local notifications have a pending-request cap. This starter solves that by precomputing the next set of reminders and skipping times that fall inside quiet windows or selected calendar events. In a production version, you would reschedule whenever settings change, when new calendar data is fetched, and during normal foreground app launches.
