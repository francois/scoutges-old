# High-level TODOs

These are the functions that are planned to be added to scoutinv. They are from the point-of-view of an end-user only.
The administrator of the system is also an end-user, and as such may have tasks written here.

The reason why there are so many 2019-07-02 is because this file was authored on 2019-07-02. All functions that already
existed at that time were flagged as "completed". Future functions will receive the appropriate date.

## Groups

* [x] Register group _2019-07-02_
* [ ] Close group
    * Cannot remove the last person in a group

## Troops

* [x] Register troop _2019-07-02_
* [x] Enroll user in troop _2019-07-02_
* [x] Remove user from troop _2019-07-02_
* [ ] Close troop

## Users

* [x] Enroll user in group _2019-07-02_
* [ ] Request access to group
* [ ] Deactivate user

## Products

* [x] Register product _2019-07-02_
* [x] Upload product picture from URL _2019-07-02_
* [x] Upload product picture from file upload _2019-07-02_
* [ ] Upload product picture from multiple file uploads
* [x] Improve product image performance  _2019-07-02_
    * Rescale images to small/medium/large variants
* [x] Change product details _2019-07-02_
* [x] Change product quantity _2019-07-02_
* [x] Remove product _2019-07-02_
* [x] View reservations on product details page _2019-07-02_
* [ ] Change instance state from product details page
* [x] Add product to categories _2019-07-04_
* [x] Remove product from categories _2019-07-04_
* [x] List product catalog _2019-07-02_
* [x] Filter product catalog by text _2019-07-03_
* [x] Filter product catalog by product category _2019-07-04_

## Events

* [x] Register internal event _2019-07-02_
* [x] Register external event _2019-07-02_
* [x] List upcoming group events
* [x] List past group events
* [ ] Edit event details
* [x] Show event details _2019-07-02_
* [x] Show event reservations _2019-07-02_
* [ ] Reserve product from catalog page
* [ ] Change product reserved quantity from event details page
* [ ] Print internal invoice
* [ ] Print external invoice
* [ ] Notify inventory director that an event is ready for assembly
* [ ] Notify troop members that an event is ready for pickup
* [ ] Notify inventory director that an event is ready for return
* [ ] Notify troop members that an event has been returned
* [ ] Notify treasury that an event has charges
* [ ] Prevent troop member from adding/removing products/consumables/kits if event is out of the draft state

## Consumables

* [ ] Register consumable
* [ ] Add consumable to event from catalog page
* [ ] Change consumable quantity on event from catalog page
* [ ] Change consumable quantity on event from event details page
* [ ] Show consumable transactions
* [ ] Change consumable quantity
    * Inventory director buys X quantity of consumable; need to reflect that in available quantity

## Kits

* [ ] Register kit
* [ ] Add instance to kit
* [ ] Remove instance from kit
* [ ] Reserve kit
    * Reject reservation request if kit has any instance that isn't loanable
* [ ] Lease kit
* [ ] Return kit
* [ ] Print kit instances on invoice

## Administrators

* [ ] Track performance metrics
* [ ] Track errors
* [ ] Migrator tool for existing https://www.scoutinv.org
