#import "RNCalendarReminders.h"
#import <React/RCTConvert.h>
#import <EventKit/EventKit.h>

@interface RNCalendarReminders ()
@property (nonatomic, strong) EKEventStore *eventStore;
@property (copy, nonatomic) NSArray *reminders;
@property (nonatomic) BOOL isAccessToEventStoreGranted;
@end

static NSString *const _id = @"id";
static NSString *const _calendarId = @"calendarId";
static NSString *const _title = @"title";
static NSString *const _location = @"location";
static NSString *const _startDate = @"startDate";
static NSString *const _dueDate = @"dueDate";
static NSString *const _completionDate = @"completionDate";
static NSString *const _notes = @"notes";
static NSString *const _alarms = @"alarms";
static NSString *const _recurrence = @"recurrence";
static NSString *const _recurrenceInterval = @"recurrenceInterval";
static NSString *const _isCompleted = @"isCompleted";
static NSString *const _priority = @"priority";

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

- (NSString *)authorizationStatusForEventStore
{
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:EKEntityTypeReminder];

    switch (status) {
        case EKAuthorizationStatusDenied:
            self.isAccessToEventStoreGranted = NO;
            return @"denied";
        case EKAuthorizationStatusRestricted:
            self.isAccessToEventStoreGranted = NO;
            return @"restricted";
        case EKAuthorizationStatusAuthorized:
            self.isAccessToEventStoreGranted = YES;
            return @"authorized";
        case EKAuthorizationStatusNotDetermined: {
            return @"undetermined";
        }
    }
}

#pragma mark -
#pragma mark Event Store Accessors

- (NSDictionary *)buildAndSaveReminder:(NSDictionary *)details
{
    if ([[self authorizationStatusForEventStore] isEqualToString:@"granted"]) {
        return @{@"success": [NSNull null], @"error": @"unauthorized to access reminders"};
    }

    EKReminder *reminder = nil;
    NSString *reminderId = [RCTConvert NSString:details[_id]];
    NSString *calendarId = [RCTConvert NSString:details[_calendarId]];
    NSString *title = [RCTConvert NSString:details[_title]];
    NSString *location = [RCTConvert NSString:details[_location]];
    NSDate *startDate = [RCTConvert NSDate:details[_startDate]];
    NSDate *dueDate = [RCTConvert NSDate:details[_dueDate]];
    NSString *notes = [RCTConvert NSString:details[_notes]];
    NSArray *alarms = [RCTConvert NSArray:details[_alarms]];
    NSString *recurrence = [RCTConvert NSString:details[_recurrence]];
    NSInteger recurrenceInterval = [RCTConvert NSInteger:details[_recurrenceInterval]];
    NSUInteger priority = [RCTConvert NSUInteger:details[_priority]];
    BOOL isCompleted = [RCTConvert BOOL:details[_isCompleted]];

    if (reminderId) {
        reminder = (EKReminder *)[self.eventStore calendarItemWithIdentifier:reminderId];
    } else {
        reminder = [EKReminder reminderWithEventStore:self.eventStore];
        reminder.calendar = [self.eventStore defaultCalendarForNewReminders];

        if (calendarId) {
            EKCalendar *calendar = [self.eventStore calendarWithIdentifier:calendarId];

            if (calendar) {
                reminder.calendar = calendar;
            }
        }
    }

    if (title) {
        reminder.title = title;
    }

    if (location) {
        reminder.location = location;
    }

    if (startDate) {
        reminder.startDateComponents = [self buidDateComponent :startDate];
    }

    if (dueDate) {
        reminder.dueDateComponents = [self buidDateComponent :dueDate];
    }

    if (notes) {
        reminder.notes = notes;
    }

    if (alarms) {
        reminder.alarms = [self createReminderAlarms:alarms];
    }

    if (recurrence) {
        NSInteger defaultInterval = 1;
        NSInteger interval = recurrenceInterval > 0 ? recurrenceInterval : defaultInterval;
        EKRecurrenceRule *rule = [self createRecurrenceRule:recurrence :interval];

        if (rule) {
            reminder.recurrenceRules = [NSArray arrayWithObject:rule];
        }
    }

    reminder.completed = isCompleted;

    reminder.priority = priority;

    return [self saveReminder:reminder];
}

- (NSDateComponents *)buidDateComponent:(NSDate *)date
{
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *dateComponent = [gregorianCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitTimeZone)
                                                           fromDate:date];

    return dateComponent;
}

- (NSDictionary *)saveReminder:(EKReminder *)reminder
{
    NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:@{@"success": [NSNull null], @"error": [NSNull null]}];

    NSError *error = nil;
    BOOL success = [self.eventStore saveReminder:reminder commit:YES error:&error];

    if (!success) {
        [response setValue:[error.userInfo valueForKey:@"NSLocalizedDescription"] forKey:@"error"];
    } else {
        [response setValue:reminder.calendarItemIdentifier forKey:@"success"];
    }
    return [response copy];
}

- (NSDictionary *)findById:(NSString *)reminderId
{
    if ([[self authorizationStatusForEventStore] isEqualToString:@"granted"]) {
        return @{@"success": [NSNull null], @"error": @"unauthorized to access calendar"};
    }

    NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:@{@"success": [NSNull null]}];

    EKReminder *reminder = (EKReminder *)[self.eventStore calendarItemWithIdentifier:reminderId];

    if (reminder) {
        [response setValue:[self serializeReminder:reminder] forKey:@"success"];
    }
    return [response copy];
}

- (NSDictionary *)deleteReminder:(NSString *)eventId
{
    if ([[self authorizationStatusForEventStore] isEqualToString:@"granted"]) {
        return @{@"success": [NSNull null], @"error": @"unauthorized to access reminders"};
    }

    NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:@{@"success": [NSNull null], @"error": [NSNull null]}];

    EKReminder *reminder = (EKReminder *)[self.eventStore calendarItemWithIdentifier:eventId];
    NSError *error = nil;
    BOOL success = [self.eventStore removeReminder:reminder commit:YES error:&error];

    if (!success) {
        [response setValue:[error.userInfo valueForKey:@"NSLocalizedDescription"] forKey:@"error"];
    } else {
        [response setValue:@YES forKey:@"success"];
    }
    return [response copy];
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

    if ([alarm objectForKey:@"structuredLocation"] && [[alarm objectForKey:@"structuredLocation"] count]) {
        NSDictionary *locationOptions = [alarm valueForKey:@"structuredLocation"];
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
        if ([alarm count] && ([alarm valueForKey:@"date"] || [alarm objectForKey:@"structuredLocation"])) {
            EKAlarm *reminderAlarm = [self createReminderAlarm:alarm];
            [reminderAlarms addObject:reminderAlarm];
        }
    }
    return [reminderAlarms copy];
}

- (NSDictionary *)addReminderAlarm:(NSString *)eventId alarm:(NSDictionary *)alarm
{
    if ([[self authorizationStatusForEventStore] isEqualToString:@"granted"]) {
        return @{@"success": [NSNull null], @"error": @"unauthorized to access reminders"};
    }

    EKReminder *reminder = (EKReminder *)[self.eventStore calendarItemWithIdentifier:eventId];
    EKAlarm *reminderAlarm = [self createReminderAlarm:alarm];

    [reminder addAlarm:reminderAlarm];

    return [self saveReminder:reminder];
}


- (NSDictionary *)addReminderAlarms:(NSString *)eventId alarms:(NSArray *)alarms
{
    if ([[self authorizationStatusForEventStore] isEqualToString:@"granted"]) {
        return @{@"success": [NSNull null], @"error": @"unauthorized to access reminders"};
    }

    EKReminder *reminder = (EKReminder *)[self.eventStore calendarItemWithIdentifier:eventId];
    reminder.alarms = [self createReminderAlarms:alarms];

    return [self saveReminder:reminder];
}

#pragma mark -
#pragma mark RecurrenceRules

-(EKRecurrenceFrequency)frequencyMatchingName:(NSString *)name
{
    EKRecurrenceFrequency recurrence = EKRecurrenceFrequencyDaily;

    if ([name isEqualToString:@"weekly"]) {
        recurrence = EKRecurrenceFrequencyWeekly;
    } else if ([name isEqualToString:@"monthly"]) {
        recurrence = EKRecurrenceFrequencyMonthly;
    } else if ([name isEqualToString:@"yearly"]) {
        recurrence = EKRecurrenceFrequencyYearly;
    }
    return recurrence;
}

-(EKRecurrenceRule *)createRecurrenceRule:(NSString *)frequency :(NSInteger)recurrenceInterval
{
    EKRecurrenceRule *rule = nil;
    NSArray *validFrequencyTypes = @[@"daily", @"weekly", @"monthly", @"yearly"];

    if ([validFrequencyTypes containsObject:frequency]) {
        rule = [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:[self frequencyMatchingName:frequency]
                                                            interval:recurrenceInterval
                                                                 end:nil];
    }
    return rule;
}

-(NSString *)nameMatchingFrequency:(EKRecurrenceFrequency)frequency
{
    switch (frequency) {
        case EKRecurrenceFrequencyWeekly:
            return @"weekly";
        case EKRecurrenceFrequencyMonthly:
            return @"monthly";
        case EKRecurrenceFrequencyYearly:
            return @"yearly";
        default:
            return @"daily";
    }
}

#pragma mark -
#pragma mark Serializers

- (NSArray *)serializeReminders:(NSArray *)reminders
{
    NSMutableArray *serializedReminders = [[NSMutableArray alloc] init];

    for (EKReminder *reminder in reminders) {
        [serializedReminders addObject:[self serializeReminder:reminder]];
    }

    return [serializedReminders copy];
}

- (NSArray *)serializeReminder:(EKReminder *)reminder
{
    NSDictionary *emptyReminder = @{
                                    _title: @"",
                                    _location: @"",
                                    _startDate: @"",
                                    _completionDate: @"",
                                    _notes: @"",
                                    _alarms: @[],
                                    _recurrence: @""
                                    };

    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    [dateFormatter setTimeZone:timeZone];
    [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [dateFormatter setDateFormat: @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z"];

    NSMutableDictionary *formedReminder = [NSMutableDictionary dictionaryWithDictionary:emptyReminder];

    [formedReminder setValue:@(reminder.isCompleted) forKey:@"isCompleted"];
    [formedReminder setValue:@(reminder.priority) forKey:_priority];

    if (reminder.calendarItemIdentifier) {
        [formedReminder setValue:reminder.calendarItemIdentifier forKey:_id];
    }

    if (reminder.calendar) {
        [formedReminder setValue:@{
                                   @"id": reminder.calendar.calendarIdentifier,
                                   @"title": reminder.calendar.title,
                                   @"source": reminder.calendar.source.title,
                                   @"allowsModifications": @(reminder.calendar.allowsContentModifications)
                                   }
                          forKey:@"calendar"];
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
                                           @"title": alarm.structuredLocation.title ?: @"",
                                           @"proximity": proximity,
                                           @"radius": @(alarm.structuredLocation.radius),
                                           @"coords": @{
                                                   @"latitude": @(alarm.structuredLocation.geoLocation.coordinate.latitude),
                                                   @"longitude": @(alarm.structuredLocation.geoLocation.coordinate.longitude)
                                                   }}
                                  forKey:@"structuredLocation"];

            }
            [alarms addObject:formattedAlarm];
        }
        [formedReminder setValue:alarms forKey:_alarms];
    }

    if (reminder.startDateComponents) {
        NSDate *reminderStartDate = [calendar dateFromComponents:reminder.startDateComponents];
        [formedReminder setValue:[dateFormatter stringFromDate:reminderStartDate] forKey:_startDate];
    }

    if (reminder.dueDateComponents) {
        NSDate *reminderDueDate = [calendar dateFromComponents:reminder.dueDateComponents];
        [formedReminder setValue:[dateFormatter stringFromDate:reminderDueDate] forKey:_dueDate];
    }

    if (reminder.completionDate) {
        [formedReminder setValue:[dateFormatter stringFromDate:reminder.completionDate] forKey:_completionDate];
    }

    if (reminder.hasRecurrenceRules) {
        NSString *frequencyType = [self nameMatchingFrequency:[[reminder.recurrenceRules objectAtIndex:0] frequency]];
        NSInteger interval = [[reminder.recurrenceRules objectAtIndex:0] interval];
        [formedReminder setValue:frequencyType forKey:_recurrence];
        [formedReminder setValue:@(interval) forKey:_recurrenceInterval];
    }

    return [formedReminder copy];

}

- (NSArray<NSDictionary *> *)serializeCalendars:(NSArray<EKCalendar *> *)calendars
{
    NSMutableArray *serializedCalendars = [[NSMutableArray alloc] init];
    
    for (EKCalendar *calendar in calendars) {
        id serializedCalendar = @{
                                  @"title": calendar.title,
                                  @"calendarIdentifier": calendar.calendarIdentifier
                                  };
        [serializedCalendars addObject:serializedCalendar];
    }
    
    return serializedCalendars;
}

#pragma mark -
#pragma mark RCT Exports

RCT_EXPORT_METHOD(authorizationStatus:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSString *status = [self authorizationStatusForEventStore];
    if (status) {
        resolve(status);
    } else {
        reject(@"error", @"authorization status error", nil);
    }
}

RCT_EXPORT_METHOD(authorizeEventStore:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    __weak RNCalendarReminders *weakSelf = self;
    [self.eventStore requestAccessToEntityType:EKEntityTypeReminder completion:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *status = granted ? @"authorized" : @"denied";
            weakSelf.isAccessToEventStoreGranted = granted;
            if (!error) {
                resolve(status);
            } else {
                reject(@"error", @"authorization request error", error);
            }
        });
    }];
}

RCT_EXPORT_METHOD(fetchReminderCalendars:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSArray<EKCalendar *> *calendars = [self.eventStore calendarsForEntityType:EKEntityTypeReminder];
    resolve([self serializeCalendars:calendars]);
}

RCT_EXPORT_METHOD(fetchAllReminders:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSPredicate *predicate = [self.eventStore predicateForRemindersInCalendars:nil];

    __weak RNCalendarReminders *weakSelf = self;
    [self.eventStore fetchRemindersMatchingPredicate:predicate completion:^(NSArray *reminders) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.reminders = reminders;

            if (reminders) {
                resolve([weakSelf serializeReminders:reminders]);
            } else {
                reject(@"error", @"calendar reminders request error", nil);
            }
        });
    }];
}

RCT_EXPORT_METHOD(fetchCompletedReminders:(NSDate *)startDate endDate:(NSDate *)endDate calendarIdentifiers:(NSArray<NSString *> *)calendarIdentifiers resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSMutableArray<EKCalendar *> *calendars = nil;
    if (calendarIdentifiers) {
        calendars = [NSMutableArray array];
        for (NSString *calendarIdentifier in calendarIdentifiers) {
            EKCalendar *calendar = [self.eventStore calendarWithIdentifier:calendarIdentifier];
            [calendars addObject:calendar];
        }
    }

    NSPredicate *predicate = [self.eventStore predicateForCompletedRemindersWithCompletionDateStarting:startDate
                                                                                                ending:endDate
                                                                                             calendars:calendars];

    __weak RNCalendarReminders *weakSelf = self;
    [self.eventStore fetchRemindersMatchingPredicate:predicate completion:^(NSArray *reminders) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.reminders = reminders;

            if (reminders) {
                resolve([weakSelf serializeReminders:reminders]);
            } else {
                reject(@"error", @"calendar reminders request error", nil);
            }
        });
    }];
}

RCT_EXPORT_METHOD(fetchIncompleteReminders:(NSDate *)startDate endDate:(NSDate *)endDate resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSPredicate *predicate = [self.eventStore predicateForIncompleteRemindersWithDueDateStarting:startDate
                                                                                          ending:endDate
                                                                                       calendars:nil];

    __weak RNCalendarReminders *weakSelf = self;
    [self.eventStore fetchRemindersMatchingPredicate:predicate completion:^(NSArray *reminders) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.reminders = reminders;

            if (reminders) {
                resolve([weakSelf serializeReminders:reminders]);
            } else {
                reject(@"error", @"calendar reminders request error", nil);
            }
        });
    }];
}

RCT_EXPORT_METHOD(findReminderById:(NSString *)reminderId resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSDictionary *response = [self findById:reminderId];

    if (!response) {
        reject(@"error", @"error finding reminder", nil);
    } else {
        resolve([response valueForKey:@"success"]);
    }
}

RCT_EXPORT_METHOD(saveReminder:(NSString *)title details:(NSDictionary *)details resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{

    NSMutableDictionary* options = [NSMutableDictionary dictionaryWithDictionary:details];
    [options setValue:title forKey:_title];

    NSDictionary *response = [self buildAndSaveReminder:options];

    if ([response valueForKey:@"success"] != [NSNull null]) {
        resolve([response valueForKey:@"success"]);
    } else {
        reject(@"error", [response valueForKey:@"error"], nil);
    }
}

RCT_EXPORT_METHOD(updateReminder:(NSString *)reminderId details:(NSDictionary *)details resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSMutableDictionary* options = [NSMutableDictionary dictionaryWithDictionary:details];
    [options setValue:reminderId forKey:_id];

    NSDictionary *response = [self buildAndSaveReminder:options];

    if ([response valueForKey:@"success"] != [NSNull null]) {
        resolve([response valueForKey:@"success"]);
    } else {
        reject(@"error", [response valueForKey:@"error"], nil);
    }
}

RCT_EXPORT_METHOD(removeReminder:(NSString *)eventId resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSDictionary *response = [self deleteReminder:eventId];

    if ([response valueForKey:@"success"] != [NSNull null]) {
        resolve([response valueForKey:@"success"]);
    } else {
        reject(@"error", [response valueForKey:@"error"], nil);
    }
}

RCT_EXPORT_METHOD(addAlarm:(NSString *)eventId alarm:(NSDictionary *)alarm resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSDictionary *response = [self addReminderAlarm:eventId alarm:alarm];

    if ([response valueForKey:@"success"] != [NSNull null]) {
        resolve([response valueForKey:@"success"]);
    } else {
        reject(@"error", [response valueForKey:@"error"], nil);
    }
}

RCT_EXPORT_METHOD(addAlarms:(NSString *)eventId alarms:(NSArray *)alarms resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSDictionary *response = [self addReminderAlarms:eventId alarms:alarms];

    if ([response valueForKey:@"success"] != [NSNull null]) {
        resolve([response valueForKey:@"success"]);
    } else {
        reject(@"error", [response valueForKey:@"error"], nil);
    }
}

RCT_EXPORT_METHOD(findCalendars:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    NSArray* calendars = [self.eventStore calendarsForEntityType:EKEntityTypeReminder];

    if (!calendars) {
        reject(@"error", @"error finding calendars", nil);
    } else {
        NSMutableArray *eventCalendars = [[NSMutableArray alloc] init];
        for (EKCalendar *calendar in calendars) {
            [eventCalendars addObject:@{
                                        @"id": calendar.calendarIdentifier,
                                        @"title": calendar.title,
                                        @"allowsModifications": @(calendar.allowsContentModifications),
                                        @"source": calendar.source.title
                                        }];
        }
        resolve(eventCalendars);
    }
}

@end
