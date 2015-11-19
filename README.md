# React-Native-CalendarReminders
React Native Module for IOS Calendar Reminders


## Install
```
npm install react-native-calendar-reminders
```
Then add RNCalendarReminders to project libraries.


## Usage

Require Native Module:
```javascript
var RNCalendarReminders = require('react-native-calendar-reminders');
```
The **EventKit.framework** will also need to be added to the project.


#### Request authorization to IOS EventStore

```javascript
RNCalendarReminders.authorizeEventStore((error, auth) => {...});
```


#### Fetch all current reminders from EventStore

```javascript
RNCalendarReminders.fetchAllReminders(reminders => {...});
```


#### Create reminder

```javascript
RNCalendarReminders.saveReminder(title, {
  location: 'location',
  notes: 'notes',
  startDate: '2016-10-01T09:45:00.000UTC'
});
```


#### Update reminder
Give an **eventId** to update and existing reminder.


```javascript
RNCalendarReminders.saveReminder(title, {
  id: eventId,
  location: location,
  notes: notes,
  startDate: '2016-10-02T09:45:00.000UTC'
});
```


#### Remove reminder

```javascript
RNCalendarReminders.removeReminder(eventId);
```
