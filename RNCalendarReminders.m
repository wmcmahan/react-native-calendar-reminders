#import "RNCalendarReminders.h"
#import "RCTConvert.h"
#import <EventKit/EventKit.h>

@interface RNCalendarReminders ()

@property (nonatomic, strong) EKEventStore *eventStore;
@property (copy, nonatomic) NSArray *reminders;
@property (nonatomic) BOOL isAccessToEventStoreGranted;

@end

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

- (void)addReminder:(NSString *)item
          startDate:(NSDateComponents *)startDate
           location:(NSString *)location
{
    if (!self.isAccessToEventStoreGranted) {
        return;
    }
    
    EKReminder *reminder = [EKReminder reminderWithEventStore:self.eventStore];
    reminder.title = item;
    reminder.location = location;
    reminder.dueDateComponents = startDate;
    reminder.calendar = [self.eventStore defaultCalendarForNewReminders];
    
    NSError *error = nil;
    BOOL success = [self.eventStore saveReminder:reminder commit:YES error:&error];
    
    if (!success) {
        // todo: handle error
    }
}

- (void)editReminder:(EKReminder *)reminder
                name:(NSString *)name
           startDate:(NSDateComponents *)startDate
            location:(NSString *)location
{
    reminder.title = name;
    reminder.location = location;
    reminder.startDateComponents = startDate;
    
    NSError *error = nil;
    BOOL success = [self.eventStore saveReminder:reminder commit:YES error:&error];
    
    if (!success) {
        // todo: handle error
    }
}

- (void)deleteReminder:(NSString *)item
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title matches %@", item];
    NSArray *results = [self.reminders filteredArrayUsingPredicate:predicate];
    
    if ([results count]) {
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSError *error = nil;
            BOOL success = [self.eventStore removeReminder:obj commit:NO error:&error];
            if (!success) {
                // todo: Handle delete error
            }
        }];
        
        NSError *commitErr = nil;
        BOOL success = [self.eventStore commit:&commitErr];
        if (!success) {
            //  todo: Handle commit error.
        }
    }
}

- (NSArray *)serializeReminders:(NSArray *)reminders
{
    NSMutableArray *serializedReminders = [[NSMutableArray alloc] init];
    
    static NSString *const title = @"title";
    static NSString *const location = @"location";
    static NSString *const startDate = @"startDate";
    static NSString *const dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z";
    
    NSDictionary *empty_reminder = @{
        title: @"",
        location: @"",
        startDate: @""
    };
    
    for (EKReminder *reminder in reminders) {
        
        NSMutableDictionary *formedReminder = [NSMutableDictionary dictionaryWithDictionary:empty_reminder];
        
        if (reminder.title) {
            [formedReminder setValue:reminder.title forKey:title];
        }
        
        if (reminder.location) {
            [formedReminder setValue:reminder.location forKey:location];
        }
        
        if (reminder.startDateComponents) {
            NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            
            NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
            
            [dateFormatter setTimeZone:timeZone];
            [dateFormatter setLocale:enUSPOSIXLocale];
            [dateFormatter setDateFormat:dateFormat];
            
            NSDate *reminderStartDate = [calendar dateFromComponents:reminder.startDateComponents];
            
            [formedReminder setValue:[dateFormatter stringFromDate:reminderStartDate] forKey:startDate];
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
    [[NSNotificationCenter defaultCenter] removeObserver:self];;
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

RCT_EXPORT_METHOD(createReminder:(NSString *)name date:(NSDate *)date location:(NSString *)location)
{
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *startDateComponents = [gregorianCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
                                                                 fromDate:date];
    
    if (name) {
        [self addReminder:name startDate:startDateComponents location:location];
    }
}

RCT_EXPORT_METHOD(updateReminder:(NSString *)lookup
                  name:(NSString *)name
                  startDate:(NSDate *)startDate
                  location:(NSString *)location)
{
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title like %@", lookup];
    NSArray *results = [self.reminders filteredArrayUsingPredicate:predicate];
    
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *startDateComponents = [gregorianCalendar components:(NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
                                                                 fromDate:startDate];
    
    if ([results count]) {
        [results enumerateObjectsUsingBlock:^(id reminder, NSUInteger idx, BOOL *stop) {
            [self editReminder:reminder
                          name:name
                     startDate:startDateComponents
                      location:location];
        }];
    }
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

RCT_EXPORT_METHOD(removeReminder:(NSString *)item)
{
    [self deleteReminder:(NSString *)item];
}

@end
