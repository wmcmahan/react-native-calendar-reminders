# React-Native-CalendarReminders
React Native Module for IOS Calendar Reminders

## Getting Libary into Project

1. Not on npm yet, but in the meantime clone or download this repo to you project directory
2. `cd` into React-Native-CalendarReminders and `npm install`
3. In XCode's project navigator, right click `Libraries` and `Add Files to [your project's name]`
4. Find your `React-Native-CalendarReminders` directory and add `RNCalendarReminders.xcodeproj`
5. Add `libRNCalendarReminders.a` to your project's `Build Phases` and `Link Binary With Libraries`
6. Click `RNCalendarReminders.xcodeproj` in the project navigator and go the `Build Settings` tab. Make sure 'All' is toggled on (instead of 'Basic'). Look for `Header Search Paths` and make sure it contains `$(SRCROOT)/node_modules/react-native/React` and mark as `recursive`.

## Usage

Require Native Module:
```javascript
var RNCalendarReminders = require('react-native').NativeModules.RNCalendarReminders;
```

Request authorization to IOS EventStore

```javascript
RNCalendarReminders.authorizeEventStore((error, auth) => {});
```

Fetch all current reminders from EventStore

```javascript
RNCalendarReminders.fetchAllReminders((reminders) => {});
```

Create new reminder

```javascript
RNCalendarReminders.saveReminder(title, {eventId: eventId', location: location, startDate: "2016-10-01T09:45:00.000UTC"});
```

Update existing reminder

```javascript
RNCalendarReminders.updateReminder(previousTitle, newtitle, startDate, location);
```
