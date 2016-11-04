//
//  TimeFilter.m
//  MAGE
//
//  Created by William Newman on 5/12/16.
//  Copyright © 2016 National Geospatial Intelligence Agency. All rights reserved.
//

#import "TimeFilter.h"

@interface TimeFilter ()
@property (strong, nonatomic) NSArray *trackingButton;
@end

@implementation TimeFilter

NSString * const kTimeFilterKey = @"timeFilterKey";


+ (TimeFilterType) getTimeFilter {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults integerForKey:kTimeFilterKey];
}

+ (void) setTimeFilter:(TimeFilterType) timeFilter {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:timeFilter forKey:kTimeFilterKey];
    [defaults synchronize];
}


+ (NSString *) getTimeFilterString {
    return [TimeFilter timeFilterStringForType:[TimeFilter getTimeFilter]];
}

+ (NSString *) timeFilterStringForType:(TimeFilterType) timeFilterType {
    switch (timeFilterType) {
        case TimeFilterAll:
            return @"All";
        case TimeFilterToday:
            return @"Today";
        case TimeFilterLast24Hours:
            return @"Last 24 Hours";
        case TimeFilterLastWeek:
            return @"Last Week";
        case TimeFilterLastMonth:
            return @"Last Month";
        default:
            return @"";
    }
}

//+ (NSPredicate *) getFilterPredicateForTimeField:(NSString *) timeField {
//    NSMutableArray *predicates = [[NSMutableArray alloc] init];
//    
//    NSPredicate *timePredicate = [TimeFilter getTimePredicateForField:timeField];
//    if (timePredicate) {
//        [predicates addObject:timePredicate];
//    }
//    
//    if ([self getImportantFilter]) {
//        [predicates addObject:[NSPredicate predicateWithFormat:@"observationImportant.important = %@", [NSNumber numberWithBool:YES]]];
//    }
//    
//    if ([self getFavoritesFilter]) {
////        [predicates addObject:[NSPredicate predicateWithFormat:@"important.important = %@", [NSNumber numberWithBool:YES]]];
//    }
//    
//    if (![predicates count]) {
//        return nil;
//    }
//
//    return [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
//}

+ (NSPredicate *) getTimePredicateForField:(NSString *) field {
    TimeFilterType timeFilter = [TimeFilter getTimeFilter];
    switch (timeFilter) {
        case TimeFilterToday: {
            NSDate *start = [[NSCalendar currentCalendar] startOfDayForDate:[NSDate date]];
            
            NSDateComponents *components = [[NSDateComponents alloc] init];
            components.day = 1;
            components.second = -1;
            NSDate *end = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:[NSDate date] options:NSCalendarMatchStrictly];
            
            return [NSPredicate predicateWithFormat:@"%K >= %@ && %K <= %@", field, start, field, end];
        }
        case TimeFilterLast24Hours: {
            NSDate *date = [[NSDate date] dateByAddingTimeInterval:-24*60*60];
            return [NSPredicate predicateWithFormat:@"%K>= %@", field, date];
        }
        case TimeFilterLastWeek: {
            NSDate *start = [[NSCalendar currentCalendar] startOfDayForDate:[NSDate date]];
            NSDate *date = [start dateByAddingTimeInterval:-7*24*60*60];
            return [NSPredicate predicateWithFormat:@"%K >= %@", field, date];
        }
        case TimeFilterLastMonth: {
            NSDateComponents *components = [[NSDateComponents alloc] init];
            components.month = -1;
            NSDate *date = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:[[NSCalendar currentCalendar] startOfDayForDate:[NSDate date]] options:NSCalendarMatchStrictly];
            
            return [NSPredicate predicateWithFormat:@"%K >= %@", field, date];
        }
        default: {
            return nil;
        }
    }
}

//+ (UIAlertController *) createFilterActionSheet {
//    
//    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Filter"
//                                                                   message:@"Filter observations and people by time"
//                                                            preferredStyle:UIAlertControllerStyleActionSheet];
//    
//    for (int type = TimeFilterAll; type <= TimeFilterLastMonth; ++type) {
//        UIAlertAction *action = [self createAlertAction:type];
//        [alert addAction:action];
//    }
//    
//    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
//    
//    return alert;
//}

//+ (UIAlertAction *) createAlertAction:(TimeFilterType) timeFilter {
//    TimeFilterType currentFilter = [TimeFilter getTimeFilter];
//
//    UIAlertAction *action = [UIAlertAction actionWithTitle:[TimeFilter timeFilterStringForType:timeFilter] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
//        [TimeFilter setTimeFilter:timeFilter];
//    }];
//    action.enabled = currentFilter != timeFilter;
//
//    return action;
//}


@end
