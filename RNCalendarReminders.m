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
{

    if (!self.isAccessToEventStoreGranted) {
        return;
    }

    EKReminder *reminder = [EKReminder reminderWithEventStore:self.eventStore];
    reminder.title = title;
    reminder.location = location;
    reminder.startDateComponents = startDateComponents;
    reminder.dueDateComponents = startDateComponents;
    reminder.completed = NO;
    reminder.calendar = [self.eventStore defaultCalendarForNewReminders];
    reminder.notes = notes;

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

- (void)editReminder:(EKReminder *)reminder
               title:(NSString *)title
           startDate:(NSDateComponents *)startDateComponents
            location:(NSString *)location
               notes:(NSString *)notes
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

- (NSArray *)serializeReminders:(NSArray *)reminders
{
    static NSString *const dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z";

    NSMutableArray *serializedReminders = [[NSMutableArray alloc] init];

    NSDictionary *empty_reminder = @{
        _title: @"",
        _location: @"",
        _startDate: @"",
        _notes: @"",
    };

    for (EKReminder *reminder in reminders) {

        NSMutableDictionary *formedReminder = [NSMutableDictionary dictionaryWithDictionary:empty_reminder];

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

        if (reminder.startDateComponents) {
            NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];

            NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];

            [dateFormatter setTimeZone:timeZone];
            [dateFormatter setDateFormat:dateFormat];

            NSDate *reminderStartDate = [calendar dateFromComponents:reminder.startDateComponents];

            [formedReminder setValue:[dateFormatter stringFromDate:reminderStartDate] forKey:_startDate];
        }

        [serializedReminders addObject:formedReminder];
    }

    NSArray *remindersCopy = [serializedReminders copy];

    return remindersCopy;
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

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *startDateComponents = [gregorianCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit)
                                                                 fromDate:startDate];

    if (eventId) {
        EKReminder *reminder = (EKReminder *)[self.eventStore calendarItemWithIdentifier:eventId];
        [self editReminder:reminder title:title startDate:startDateComponents location:location notes:notes];

    } else {
        [self addReminder:title startDate:startDateComponents location:location notes:notes];
    }
}

RCT_EXPORT_METHOD(removeReminder:(NSString *)eventId)
{
    [self deleteReminder:(NSString *)eventId];
}

@end
