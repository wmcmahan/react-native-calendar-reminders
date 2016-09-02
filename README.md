# React-Native-Calendar-Reminders
React Native Module for IOS Calendar Reminders


## Install
```
npm install --save react-native-calendar-reminders
```
Then add `RNCalendarReminders`, as well as `EventKit.framework` to project libraries.

## Usage

Require the `react-native-calendar-reminders` module and React Native's `NativeAppEventEmitter` module.
```javascript
import RNCalendarReminders from 'react-native-calendar-reminders';
import {NativeAppEventEmitter} from 'react-native';
```

## Properties

| Property        | Value            | Description |
| :--------------- | :---------------- | :----------- |
| id              | String (read only)             | Unique id for the reminder. |
| title           | String             | The title for the reminder. |
| startDate       | Date             | The start date of the reminder. |
| dueDate         | Date             | The date by which the reminder should be completed. |
| completionDate  | Date (read only) | The date on which the reminder was completed. |
| location        | String           | The location associated with the reminder. |
| notes           | String           | The notes associated with the reminder. |
| alarms          | Array            | The alarms associated with the reminder, as an array of alarm objects. |
| recurrence      | String           | The simple recurrence frequency of the reminder ['daily', 'weekly', 'monthly', 'yearly']. |
| isCompleted     | Bool             | A Boolean value determining whether or not the reminder is marked completed. |

## Events

| Name        | Body            | Description |
| :--------------- | :---------------- | :----------- |
| remindersChanged      | reminders           | List of all reminders in the store |
| reminderSaveSuccess   | reminder id         | The ID of the successfully saved reminder |
| reminderSaveError     | error message       | Error that occurred during save. |

Example:

```javascript
componentWillMount () {
  this.eventEmitter = NativeAppEventEmitter.addListener('remindersChanged', reminders => {...});
}

componentWillUnmount () {
  this.eventEmitter.remove();
}
```

## Get authorization status for IOS EventStore
Finds the current authorization status: "denied", "restricted", "authorized" or "undetermined".

```javascript
RNCalendarReminders.authorizationStatus(({status}) => {...});
```

## Request authorization to IOS EventStore
Authorization must be granted before accessing reminders.

```javascript
RNCalendarReminders.authorizeEventStore(({status}) => {...});
```


## Fetch all reminders from EventStore

```javascript
RNCalendarReminders.fetchAllReminders(reminders => {...});
```
## Create reminder

```
RNCalendarReminders.saveReminder(title, settings);
```
Example:
```javascript
RNCalendarReminders.saveReminder('title', {
  location: 'location',
  notes: 'notes',
  startDate: '2016-10-01T09:45:00.000UTC'
});
```

## Create reminder with alarms

### Alarm options:

| Property        | Value            | Description |
| :--------------- | :------------------| :----------- |
| date           | Date or Number    | If a Date is given, an alarm will be set with an absolute date. If a Number is given, an alarm will be set with a relative offset (in minutes) from the start date. |
| structuredLocation | Object             | The location to trigger an alarm. |

### Alarm structuredLocation properties:

| Property        | Value            | Description |
| :--------------- | :------------------| :----------- |
| title           | String  | The title of the location.|
| proximity | String             | A value indicating how a location-based alarm is triggered. Possible values: `enter`, `leave`, `none`. |
| radius | Number             | A minimum distance from the core location that would trigger the reminder's alarm. |
| coords | Object             | The geolocation coordinates, as an object with latitude and longitude properties |

Example with date:

```javascript
RNCalendarReminders.saveReminder('title', {
  location: 'location',
  notes: 'notes',
  startDate: '2016-10-01T09:45:00.000UTC',
  alarms: [{
    date: -1 // or absolute date
  }]
});
```
Example with structuredLocation:

```javascript
RNCalendarReminders.saveReminder('title', {
  location: 'location',
  notes: 'notes',
  startDate: '2016-10-01T09:45:00.000UTC',
  alarms: [{
    structuredLocation: {
      title: 'title',
      proximity: 'enter',
      radius: 500,
      coords: {
        latitude: 30.0000,
        longitude: 97.0000
      }
    }
  }]
});
```

Example with recurrence:

```javascript
RNCalendarReminders.saveReminder('title', {
  location: 'location',
  notes: 'notes',
  startDate: '2016-10-01T09:45:00.000UTC',
  alarms: [{
    date: -1 // or absolute date
  }],
  recurrence: 'daily'
});
```

## Update reminder
Pass the unique reminder **id** to update an existing reminder.

```javascript
RNCalendarReminders.updateReminder('id', {
  title: 'another title'
});
```

Or save save the reminder again with **id** property set in the optional settings.


```javascript
RNCalendarReminders.saveReminder('title', {
  id: 'id',
  location: 'location',
  notes: 'notes',
  startDate: '2016-10-02T09:45:00.000UTC'
});
```

## Update reminder alarms
Pass the unique reminder **id** and an array of alarm **options** to update an existing reminder. Note: This will overwrite any alarms already set on the reminder.

```javascript
RNCalendarReminders.addAlarms('id', [{
  date: -2 // or absolute date
}]);
```

## Update reminder with added alarm
Pass the unique reminder **id** and alarm **options** object to add new alarm.

```javascript
RNCalendarReminders.addAlarm('id', {
  date: -3 // or absolute date
});
```

## Remove reminder
Pass the unique reminder **id** to remove an existing reminder.

```javascript
RNCalendarReminders.removeReminder('id');
```
