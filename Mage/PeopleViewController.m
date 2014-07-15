//
//  PeopleViewController.m
//  Mage
//
//  Created by Billy Newman on 7/14/14.
//

#import "PeopleViewController.h"
#import "PersonImage.h"
#import "User+helper.h"
#import "Location+helper.h"
#import "NSDate+DateTools.h"
#import "PersonTableViewCell.h"

@implementation PeopleViewController

- (NSFetchedResultsController *) locationResultsController {
	
	if (_locationResultsController != nil) {
		return _locationResultsController;
	}
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"Location" inManagedObjectContext:_managedObjectContext]];
	[fetchRequest setSortDescriptors:[NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO]]];
	
	_locationResultsController = [[NSFetchedResultsController alloc]
								  initWithFetchRequest:fetchRequest
								  managedObjectContext:_managedObjectContext
								  sectionNameKeyPath:nil
								  cacheName:nil];
	
	[_locationResultsController setDelegate:self];
	
	return _locationResultsController;
}

- (void)viewDidLoad {
    [super viewDidLoad];
		
	NSError *error;
    if (![[self locationResultsController] performFetch:&error]) {
        // Update to handle the error appropriately.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        exit(-1);  // Fail
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id  sectionInfo = [[_locationResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (void) configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
	PersonTableViewCell *personCell = (PersonTableViewCell *) cell;
	
	Location *location = [_locationResultsController objectAtIndexPath:indexPath];
	User *user = [User fetchUserForId:location.userId inManagedObjectContext:_managedObjectContext];
	[personCell.icon setImage:[PersonImage imageForTimestamp:location.timestamp]];
	personCell.name.text = user.name;
	personCell.email.text = user.email;
	personCell.timestamp.text = location.timestamp.timeAgoSinceNow;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
    static NSString *CellIdentifier = @"personCell";
	
    PersonTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
        cell = [[PersonTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
	
	[self configureCell:cell atIndexPath:indexPath];
	
    return cell;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller is about to start sending change notifications, so prepare the table view for updates.
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id) anObject atIndexPath:(NSIndexPath *) indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *) newIndexPath {
	
    UITableView *tableView = self.tableView;
	
    switch(type) {
			
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
			
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
			
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
			
        case NSFetchedResultsChangeMove:
			[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
			[tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
			break;
    }
}

- (void) controller:(NSFetchedResultsController *)controller didChangeSection:(id) sectionInfo atIndex:(NSUInteger) sectionIndex forChangeType:(NSFetchedResultsChangeType) type {
	
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
			
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller has sent all current change notifications, so tell the table view to process all updates.
    [self.tableView endUpdates];
}


@end