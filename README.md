# React Native Calendar Reminders
React Native Module for IOS Calendar Reminders

## Install
```
npm install --save react-native-calendar-reminders
```

## Link Library

```
react-native link react-native-calendar-reminders
```

## plist - Usage Description

Setting up privacy usage descriptions may also be require depending on which iOS version is supported. This involves updating the Property List, `Info.plist`, with the corresponding key for the EKEventStore api. [Info.plist reference](https://developer.apple.com/library/content/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html).

For updating the `Info.plist` key/value via Xcode, add a `Privacy - Reminders Usage Description` key with a usage description as the value.

## Usage

Require the `react-native-calendar-reminders` module.

```javascript
import RNCalendarReminders from 'react-native-calendar-reminders';
```

- React-Native 0.40 and above use 1.1.0 and above
- React-Native 0.39 and below use 1.0.0 and below


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
| recurrenceInterval | String        | The interval between instances of this recurrence. For example, a weekly recurrence rule with an interval of 2 occurs every other week. Must be greater than 0. |
| isCompleted     | Bool             | A Boolean value determining whether or not the reminder is marked completed. |


## authorizationStatus
Get authorization status for IOS EventStore.

```javascript
RNCalendarReminders.authorizationStatus()
```

Returns: Promise 
- fulfilled: String - `denied`, `restricted`, `authorized` or `undetermined`
- rejected: Error

Example:
```javascript
RNCalendarReminders.authorizationStatus()
  .then(status => {
    // handle status
  })
  .catch(error => {
   // handle error
  });
```

## authorizeEventStore
Request authorization to IOS EventStore. Authorization must be granted before accessing calendar events.

```javascript
RNCalendarReminders.authorizeEventStore()
```

Returns: Promise 
 - fulfilled: String - `denied`, `restricted`, `authorized` or `undetermined`
 - rejected: Error

Example:
```javascript
RNCalendarReminders.authorizeEventStore()
  .then(status => {
    // handle status
  })
  .catch(error => {
   // handle error
  });
```


## fetchAllReminders
Find all reminders.

```javascript
RNCalendarReminders.fetchAllReminders()
```

Returns: Promise 
 - fulfilled: Array - List of reminders
 - rejected: Error

Example:
```javascript
RNCalendarReminders.fetchAllReminders()
  .then(reminders => {
    // handle reminders
  })
  .catch(error => {
   // handle error
  });
```

## fetchCompletedReminders
Finds completed reminders in a set of calendars within an optional range.

```javascript
RNCalendarReminders.fetchCompletedReminders()
```

Parameters: 
 - startDate: Date - The starting bound of the range to search.
 - endDate: Date - The ending bound of the range to search.

Returns: Promise 
 - fulfilled: Array - List of completed reminders from range
 - rejected: Error

Example:
```javascript
RNCalendarReminders.fetchCompletedReminders(startDate, endDate)
  .then(reminders => {
    // handle reminders
  })
  .catch(error => {
   // handle error
  });
```


## fetchIncompleteReminders
Finds incomplete reminders in a set of calendars within an optional range.

```javascript
RNCalendarReminders.fetchIncompleteReminders(startDate, endDate)
```

Parameters: 
 - startDate: Date - The starting bound of the range to search.
 - endDate: Date - The ending bound of the range to search.

Returns: Promise 
 - fulfilled: Array - List of incomplete reminders from range
 - rejected: Error

Example:
```javascript
RNCalendarReminders.fetchIncompleteReminders(startDate, endDate)
  .then(reminders => {
    // handle reminders
  })
  .catch(error => {
   // handle error
  });
```

## saveReminder
Creates a new reminder.

```
RNCalendarReminders.saveReminder(title, settings);
```

Parameters: 
 - title: String - The title of the reminder.
 - settings: Object - The settings for the reminder. See available properties above.

Returns: Promise 
 - fulfilled: String - ID of created reminder
 - rejected: Error

Example:
```javascript
RNCalendarReminders.saveReminder('title', {
    location: 'location',
    notes: 'notes',
    startDate: '2016-10-01T09:45:00.000UTC'
  })
  .then(id => {
    // handle success
  })
  .catch(error => {
   // handle error
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

Example with recurrenceInterval:

```javascript
RNCalendarReminders.saveReminder('title', {
  location: 'location',
  notes: 'notes',
  startDate: '2016-10-01T09:45:00.000UTC',
  alarms: [{
    date: -1 // or absolute date
  }],
  recurrence: 'weekly',
  recurrenceInterval: '2'
});
```

## updateReminder
Updates an existing reminder.

```javascript
RNCalendarReminders.updateReminder(id, settings)
```

Parameters: 
 - id: String - The unique ID of the reminder to edit.
 - settings: Object - The settings for the reminder. See available properties above.

Returns: Promise 
 - fulfilled: String - ID of updated reminder
 - rejected: Error

Example:
```javascript
RNCalendarReminders.updateReminder('465E5BEB-F8B0-49D6-9174-272A4E5DEEFC', {
    title: 'another title',
    startDate: '2016-10-01T09:55:00.000UTC',
  })
  .then(id => {
    // handle success
  })
  .catch(error => {
   // handle error
  });
```

Or save save the reminder again with **id** property set in the optional settings.

Example:
```javascript
RNCalendarReminders.saveReminder('title', {
    id: 'id',
    location: 'location',
    notes: 'notes',
    startDate: '2016-10-02T09:45:00.000UTC'
  })
  .then(id => {
    // handle success
  })
  .catch(error => {
   // handle error
  });
```

## addAlarms
Update reminder with alarms. This will overwrite any alarms already set on the reminder.

```javascript
RNCalendarReminders.addAlarms(id, alarms)
```

Parameters: 
 - id: String - The unique ID of the reminder to add alarms to.
 - alarm: Objec - Alarm to add to reminder. See available alarm properties above.

Returns: Promise 
 - fulfilled: String - ID of reminder with alarms
 - rejected: Error

```javascript
RNCalendarReminders.addAlarms('465E5BEB-F8B0-49D6-9174-272A4E5DEEFC', [{
    date: -2 // or absolute date
  }])
  .then(id => {
    // handle success
  })
  .catch(error => {
   // handle error
  });
```

## addAlarm
Update reminder with added alarm

```javascript
RNCalendarReminders.addAlarm(id, alarm)
```

Parameters: 
 - id: String - The unique ID of the reminder to add alarms to.
 - alarms: Array - List of alarms to add to reminder. See available alarm properties above.

Returns: Promise 
 - fulfilled: String - ID of reminder with alarms
 - rejected: Error


```javascript
RNCalendarReminders.addAlarm('465E5BEB-F8B0-49D6-9174-272A4E5DEEFC', {
    date: -3 // or absolute date
  })
  .then(id => {
    // handle success
  })
  .catch(error => {
   // handle error
  });
```

## removeReminder
Remove existing reminder

Parameters: 
 - id: String - The unique ID of the reminder to remove.

Returns: Promise 
 - fulfilled: Bool - True if successful
 - rejected: Error

```javascript
RNCalendarReminders.removeReminder('465E5BEB-F8B0-49D6-9174-272A4E5DEEFC')
.then(successful => {
    // handle success
  })
  .catch(error => {
   // handle error
  });
```
