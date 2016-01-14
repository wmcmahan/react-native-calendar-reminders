#import "RNCalendarReminders.h"
#import "RCTConvert.h"
#import <EventKit/EventKit.h>

@interface RNCalendarReminders ()
@property (nonatomic, strong) EKEventStore *eventStore;
@property (copy, nonatomic) NSArray *reminders;
@property (nonatomic) BOOL isAccessToEventStoreGranted;
@end

static NSString *const _id = @"id";
static NSString *const _title = @"title";
static NSString *const _location = @"location";
static NSString *const _startDate = @"startDate";
static NSString *const _notes = @"notes";
static NSString *const _alarms = @"alarms";

@implementation RNCalendarReminders

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

#pragma mark -
#pragma mark Event Store Initialize

- (EKEventStore *)eventStore
{
    if (!_eventStore) {
        _eventStore = [[EKEventStore alloc] init];
    }
    return _eventStore;
}

- (NSArray *)reminders
{
    if (!_reminders) {
        _reminders = [[NSArray alloc] init];
    }
    return _reminders;
}

#pragma mark -
#pragma mark Event Store Authorization

- (void)authorizationStatusForAccessEventStore
{
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:EKEntityTypeReminder];

    switch (status) {
        case EKAuthorizationStatusDenied:
        case EKAuthorizationStatusRestricted: {
            self.isAccessToEventStoreGranted = NO;
            break;
        }
        case EKAuthorizationStatusAuthorized:
            self.isAccessToEventStoreGranted = YES;
            [self addNotificationCenter];
            break;
        case EKAuthorizationStatusNotDetermined: {
            [self requestCalendarAccess];
            break;
        }
    }
}

-(void)requestCalendarAccess
{
    __weak RNCalendarReminders *weakSelf = self;
    [self.eventStore requestAccessToEntityType:EKEntityTypeReminder completion:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.isAccessToEventStoreGranted = granted;
            [weakSelf addNotificationCenter];
        });
    }];
}

#pragma mark -
#pragma mark Event Store Accessors

- (void)addReminder:(NSString *)title
          startDate:(NSDateComponents *)startDateComponents
           location:(NSString *)location
              notes:(NSString *)notes
             alarms:(NSArray *)alarms
{
    if (!self.isAccessToEventStoreGranted) {
        return;
    }

    EKReminder *reminder = [EKReminder reminderWithEventStore:self.eventStore];
    reminder.calendar = [self.eventStore defaultCalendarForNewReminders];
    reminder.title = title;
    reminder.location = location;
    reminder.dueDateComponents = startDateComponents;
    reminder.startDateComponents = startDateComponents;
    reminder.completed = NO;
    reminder.notes = notes;

    if (alarms) {
        reminder.alarms = [self createReminderAlarms:alarms];
    }

    [self saveReminder:reminder];
}


- (void)editReminder:(EKReminder *)reminder
               title:(NSString *)title
           startDate:(NSDateComponents *)startDateComponents
            location:(NSString *)location
               notes:(NSString *)notes
              alarms:(NSArray *)alarms
{
    if (!self.isAccessToEventStoreGranted) {
        return;
    }

    reminder.title = title;
    reminder.location = location;
    reminder.dueDateComponents = startDateComponents;
    reminder.startDateComponents = startDateComponents;
    reminder.completed = NO;
    reminder.notes = notes;

    if (alarms) {
        reminder.alarms = [self createReminderAlarms:alarms];
    }

    [self saveReminder:reminder];
}


-(void)saveReminder:(EKReminder *)reminder
{
    NSError *error = nil;
    BOOL success = [self.eventStore saveReminder:reminder commit:YES error:&error];

    if (!success) {
        [self.bridge.eventDispatcher sendAppEventWithName:@"EventReminderError"
                                                     body:@{@"error": @"Error saving reminder"}];
    } else {
        [self.bridge.eventDispatcher sendAppEventWithName:@"EventReminderSaved"
                                                     body:reminder.calendarItemIdentifier];
    }
}


- (void)deleteReminder:(NSString *)eventId
{
    if (!self.isAccessToEventStoreGranted) {
        return;
    }

    EKReminder *reminder = (EKReminder *)[self.eventStore calendarItemWithIdentifier:eventId];
    NSError *error = nil;
    BOOL success = [self.eventStore removeReminder:reminder commit:YES error:&error];

    if (!success) {
        [self.bridge.eventDispatcher sendAppEventWithName:@"EventReminderError"
                                                     body:@{@"error": @"Error removing reminder"}];
    }
}

#pragma mark -
#pragma mark Alarms


- (EKAlarm *)createReminderAlarm:(NSDictionary *)alarm
{
    EKAlarm *reminderAlarm = nil;
    id alarmDate = [alarm valueForKey:@"date"];

    if ([alarmDate isKindOfClass:[NSString class]]) {
        reminderAlarm = [EKAlarm alarmWithAbsoluteDate:[RCTConvert NSDate:alarmDate]];
    } else if ([alarmDate isKindOfClass:[NSNumber class]]) {
        int minutes = [alarmDate intValue];
        reminderAlarm = [EKAlarm alarmWithRelativeOffset:(60 * minutes)];
    } else {
        reminderAlarm = [[EKAlarm alloc] init];
    }

    if ([alarm objectForKey:@"location"] && [[alarm objectForKey:@"location"] count]) {
        NSDictionary *locationOptions = [alarm valueForKey:@"location"];
        NSDictionary *geo = [locationOptions valueForKey:@"coords"];
        CLLocation *geoLocation = [[CLLocation alloc] initWithLatitude:[[geo valueForKey:@"latitude"] doubleValue]
                                                             longitude:[[geo valueForKey:@"longitude"] doubleValue]];

        reminderAlarm.structuredLocation = [EKStructuredLocation locationWithTitle:[locationOptions valueForKey:@"title"]];
        reminderAlarm.structuredLocation.geoLocation = geoLocation;
        reminderAlarm.structuredLocation.radius = [[locationOptions valueForKey:@"radius"] doubleValue];

        if ([[locationOptions valueForKey:@"proximity"] isEqualToString:@"enter"]) {
            reminderAlarm.proximity = EKAlarmProximityEnter;
        } else if ([[locationOptions valueForKey:@"proximity"] isEqualToString:@"leave"]) {
            reminderAlarm.proximity = EKAlarmProximityLeave;
        } else {
            reminderAlarm.proximity = EKAlarmProximityNone;
        }
    }
    return reminderAlarm;
}


- (NSArray *)createReminderAlarms:(NSArray *)alarms
{
    NSMutableArray *reminderAlarms = [[NSMutableArray alloc] init];
    for (NSDictionary *alarm in alarms) {
        if ([alarm count] && ([alarm valueForKey:@"date"] || [alarm objectForKey:@"location"])) {
            EKAlarm *reminderAlarm = [self createReminderAlarm:alarm];
            [reminderAlarms addObject:reminderAlarm];
        }
    }
    return [reminderAlarms copy];
}


- (void)addReminderAlarm:(NSString *)eventId alarm:(NSDictionary *)alarm
{
    if (!self.isAccessToEventStoreGranted) {
        return;
    }

    EKReminder *reminder = (EKReminder *)[self.eventStore calendarItemWithIdentifier:eventId];
    EKAlarm *reminderAlarm = [self createReminderAlarm:alarm];
    [reminder addAlarm:reminderAlarm];

    [self saveReminder:reminder];
}


- (void)addReminderAlarms:(NSString *)eventId alarms:(NSArray *)alarms
{
    if (!self.isAccessToEventStoreGranted) {
        return;
    }

    EKReminder *reminder = (EKReminder *)[self.eventStore calendarItemWithIdentifier:eventId];
    reminder.alarms = [self createReminderAlarms:alarms];

    [self saveReminder:reminder];
}

#pragma mark -
#pragma mark Serializers

- (NSArray *)serializeReminders:(NSArray *)reminders
{
    NSMutableArray *serializedReminders = [[NSMutableArray alloc] init];

    NSDictionary *emptyReminder = @{
                                    _title: @"",
                                    _location: @"",
                                    _startDate: @"",
                                    _notes: @"",
                                    _alarms: @[]
                                    };

    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    [dateFormatter setTimeZone:timeZone];
    [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [dateFormatter setDateFormat: @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z"];

    for (EKReminder *reminder in reminders) {

        NSMutableDictionary *formedReminder = [NSMutableDictionary dictionaryWithDictionary:emptyReminder];

        if (reminder.calendarItemIdentifier) {
            [formedReminder setValue:reminder.calendarItemIdentifier forKey:_id];
        }

        if (reminder.title) {
            [formedReminder setValue:reminder.title forKey:_title];
        }

        if (reminder.notes) {
            [formedReminder setValue:reminder.notes forKey:_notes];
        }

        if (reminder.location) {
            [formedReminder setValue:reminder.location forKey:_location];
        }

        if (reminder.hasAlarms) {
            NSMutableArray *alarms = [[NSMutableArray alloc] init];

            for (EKAlarm *alarm in reminder.alarms) {
                NSMutableDictionary *formattedAlarm = [[NSMutableDictionary alloc] init];
                NSString *alarmDate = nil;

                if (alarm.absoluteDate) {
                    alarmDate = [dateFormatter stringFromDate:alarm.absoluteDate];
                } else if (alarm.relativeOffset) {
                    NSDate *reminderStartDate = nil;
                    if (reminder.startDateComponents) {
                        reminderStartDate = [calendar dateFromComponents:reminder.startDateComponents];
                    } else {
                        reminderStartDate = [NSDate date];
                    }
                    alarmDate = [dateFormatter stringFromDate:[NSDate dateWithTimeInterval:alarm.relativeOffset
                                                                                 sinceDate:reminderStartDate]];
                }
                [formattedAlarm setValue:alarmDate forKey:@"date"];

                if (alarm.structuredLocation) {
                    NSString *proximity = nil;
                    switch (alarm.proximity) {
                        case EKAlarmProximityEnter:
                            proximity = @"enter";
                            break;
                        case EKAlarmProximityLeave:
                            proximity = @"leave";
                            break;
                        default:
                            proximity = @"None";
                            break;
                    }
                    [formattedAlarm setValue:@{
                                               @"title": alarm.structuredLocation.title,
                                               @"proximity": proximity,
                                               @"radius": @(alarm.structuredLocation.radius),
                                               @"coords": @{
                                                       @"latitude": @(alarm.structuredLocation.geoLocation.coordinate.latitude),
                                                       @"longitude": @(alarm.structuredLocation.geoLocation.coordinate.longitude)
                                                       }}
                                      forKey:@"location"];

                }
                [alarms addObject:formattedAlarm];
            }
            [formedReminder setValue:alarms forKey:_alarms];
        }

        if (reminder.startDateComponents) {
            NSDate *reminderStartDate = [calendar dateFromComponents:reminder.startDateComponents];
            [formedReminder setValue:[dateFormatter stringFromDate:reminderStartDate] forKey:_startDate];
        }

        [serializedReminders addObject:formedReminder];
    }

    return [serializedReminders copy];
}

#pragma mark -
#pragma mark notifications


- (void)addNotificationCenter
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(calendarEventReminderReceived:)
                                                 name:EKEventStoreChangedNotification
                                               object:nil];
}


- (void)calendarEventReminderReceived:(NSNotification *)notification
{
    NSPredicate *predicate = [self.eventStore predicateForRemindersInCalendars:nil];

    __weak RNCalendarReminders *weakSelf = self;
    [self.eventStore fetchRemindersMatchingPredicate:predicate completion:^(NSArray *reminders) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.bridge.eventDispatcher sendAppEventWithName:@"EventReminder"
                                                             body:[weakSelf serializeReminders:reminders]];
        });
    }];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark RCT Exports

RCT_EXPORT_METHOD(authorizeEventStore:(RCTResponseSenderBlock)callback)
{
    [self authorizationStatusForAccessEventStore];
    callback(@[@(self.isAccessToEventStoreGranted)]);
}

RCT_EXPORT_METHOD(fetchAllReminders:(RCTResponseSenderBlock)callback)
{
    NSPredicate *predicate = [self.eventStore predicateForRemindersInCalendars:nil];

    __weak RNCalendarReminders *weakSelf = self;
    [self.eventStore fetchRemindersMatchingPredicate:predicate completion:^(NSArray *reminders) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.reminders = reminders;
            callback(@[[weakSelf serializeReminders:reminders]]);
        });
    }];
}

RCT_EXPORT_METHOD(saveReminder:(NSString *)title details:(NSDictionary *)details)
{
    NSString *eventId = [RCTConvert NSString:details[_id]];
    NSString *location = [RCTConvert NSString:details[_location]];
    NSDate *startDate = [RCTConvert NSDate:details[_startDate]];
    NSString *notes = [RCTConvert NSString:details[_notes]];
    NSArray *alarms = [RCTConvert NSArray:details[_alarms]];

    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *startDateComponents = [gregorianCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit)
                                                                 fromDate:startDate];

    if (eventId) {
        EKReminder *reminder = (EKReminder *)[self.eventStore calendarItemWithIdentifier:eventId];
        [self editReminder:reminder
                     title:title
                 startDate:startDateComponents
                  location:location
                     notes:notes
                    alarms:alarms];

    } else {
        [self addReminder:title
                startDate:startDateComponents
                 location:location
                    notes:notes
                   alarms:alarms];
    }
}

RCT_EXPORT_METHOD(removeReminder:(NSString *)eventId)
{
    [self deleteReminder:eventId];
}

RCT_EXPORT_METHOD(addAlarm:(NSString *)eventId alarm:(NSDictionary *)alarm)
{
    [self addReminderAlarm:eventId alarm:alarm];
}

RCT_EXPORT_METHOD(addAlarms:(NSString *)eventId alarms:(NSArray *)alarms)
{
    [self addReminderAlarms:eventId alarms:alarms];
}

@end
