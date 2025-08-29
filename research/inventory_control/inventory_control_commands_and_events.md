# Accountex Inventory Control - Commands and Events

## Overview

This document provides a comprehensive list of all commands and events in the Inventory Control domain. Commands represent requests to change system state, while events represent facts about what has happened in the system. The design follows CQRS (Command Query Responsibility Segregation) and Event Sourcing patterns using the Commanded framework.

## Item Management Commands and Events

### Item Lifecycle Management

#### CreateItem Command
**Purpose**: Creates a new inventory item in the system.

**Description**: Establishes new inventory item including basic information, costing method, tracking requirements, and configuration settings. Validates item data and initializes item for inventory operations with appropriate defaults.

**Parameters**:
- `item_id`: Unique item identifier
- `sku`: Stock keeping unit code
- `description`: Item description
- `item_type`: Type of item (stock, non_stock, service, kit)
- `primary_uom`: Primary unit of measurement
- `costing_method`: Cost calculation method (FIFO, LIFO, average, standard)
- `inventory_type_id`: Item classification type
- `specifications`: Item specifications and attributes

**Business Rules**:
- SKU must be unique within system
- Item type determines available operations
- Costing method cannot be changed after transactions exist
- Primary UOM cannot be changed after transactions
- Specifications must match inventory type requirements

---

#### UpdateItemSpecifications Command
**Purpose**: Updates item specifications and configuration settings.

**Description**: Modifies item specifications including technical attributes, configuration parameters, and operational settings. Maintains specification history and validates specification consistency.

**Parameters**:
- `item_id`: Item to update
- `specifications`: Updated specifications map
- `configuration_changes`: Configuration parameter updates
- `effective_date`: When changes become effective
- `updated_by`: User making changes
- `change_reason`: Justification for specification changes

**Business Rules**:
- Specification changes must be compatible with item type
- Critical specifications require approval for changes
- Changes affecting costing require financial approval
- Historical specifications preserved for audit

---

#### ActivateItem Command
**Purpose**: Activates inactive inventory item for transactions.

**Description**: Changes item status to active including validation of readiness, configuration completeness, and business rule compliance. Enables item for all inventory operations.

**Parameters**:
- `item_id`: Item to activate
- `activation_reason`: Reason for activation
- `effective_date`: When activation becomes effective
- `configuration_validation`: Validation of item setup
- `activated_by`: User authorizing activation

**Business Rules**:
- Item configuration must be complete
- All required specifications must be defined
- Costing method must be properly configured
- Activation authorization required

---

#### DeactivateItem Command
**Purpose**: Deactivates inventory item with proper cleanup and validation.

**Description**: Changes item status to inactive including validation of zero inventory, transaction completion, and cleanup coordination. Prevents new transactions while preserving historical data.

**Parameters**:
- `item_id`: Item to deactivate
- `deactivation_reason`: Reason for deactivation
- `effective_date`: When deactivation becomes effective
- `inventory_disposition`: How to handle remaining inventory
- `deactivated_by`: User authorizing deactivation

**Business Rules**:
- Item must have zero on-hand quantity across all locations
- All pending transactions must be completed
- Deactivation authorization required
- Historical data preserved for audit

---

### Item Events

#### ItemCreated Event
**Purpose**: Records creation of new inventory item.

**Description**: Emitted when inventory item is successfully created. Contains item details and triggers initialization of item-related processes and projections across warehouses.

**Data**:
- `item_id`: Created item identifier
- `sku`: Stock keeping unit code
- `item_type`: Type of item created
- `costing_method`: Configured costing method
- `inventory_type_id`: Item classification
- `created_by`: User creating item
- `created_at`: Creation timestamp

**Downstream Effects**:
- Initializes item in all warehouse locations
- Sets up costing and valuation tracking
- Creates item availability projections
- Triggers pricing setup if configured

---

#### ItemSpecificationsUpdated Event
**Purpose**: Records updates to item specifications and configuration.

**Description**: Emitted when item specifications are updated. Contains specification changes and triggers validation of dependent configurations and processes.

**Data**:
- `item_id`: Updated item
- `previous_specifications`: Former specifications
- `new_specifications`: Updated specifications
- `specification_changes`: Detailed change summary
- `effective_date`: When changes become effective
- `updated_by`: User making changes

**Downstream Effects**:
- Updates item configuration projections
- Validates impact on existing transactions
- Updates costing calculations if affected
- Triggers dependent system updates

---

#### ItemStatusChanged Event
**Purpose**: Records item status transitions with audit trail.

**Description**: Emitted when item status changes (active, inactive, discontinued). Contains status change details and triggers appropriate business process updates.

**Data**:
- `item_id`: Item with status change
- `previous_status`: Former status
- `new_status`: Updated status
- `change_reason`: Reason for status change
- `effective_date`: When change becomes effective
- `changed_by`: User authorizing change

**Downstream Effects**:
- Updates item availability for transactions
- Triggers inventory disposition if deactivated
- Updates planning and procurement processes
- Creates status change audit trail

---

## Stock Movement Commands and Events

### Inventory Transactions

#### ReceiveStock Command
**Purpose**: Records receipt of inventory into warehouse location.

**Description**: Processes inventory receipt including quantity validation, cost application, lot/serial assignment, and location placement. Updates inventory balances and triggers downstream processes.

**Parameters**:
- `receipt_id`: Unique receipt transaction identifier
- `item_id`: Item being received
- `location_id`: Warehouse location for receipt
- `quantity`: Quantity being received
- `unit_cost`: Cost per unit received
- `lot_number`: Lot number if lot-controlled
- `serial_numbers`: Serial numbers if serialized
- `receipt_date`: Date of receipt
- `source_reference`: Source document reference (PO, transfer, etc.)

**Business Rules**:
- Quantity must be positive
- Location must be valid and active
- Unit cost must be reasonable and positive
- Lot/serial numbers required for controlled items
- Receipt date cannot be future-dated

---

#### IssueStock Command
**Purpose**: Issues inventory from warehouse location for consumption.

**Description**: Processes inventory issue including availability validation, cost calculation, lot/serial tracking, and balance updates. Handles FIFO/LIFO cost consumption and triggers downstream processes.

**Parameters**:
- `issue_id`: Unique issue transaction identifier
- `item_id`: Item being issued
- `location_id`: Source warehouse location
- `quantity`: Quantity being issued
- `destination_reference`: Where inventory is going (work order, shipment, etc.)
- `lot_selection`: Specific lot selection if lot-controlled
- `serial_selection`: Specific serial selection if serialized
- `issue_date`: Date of issue

**Business Rules**:
- Sufficient inventory must be available at location
- Lot/serial selection required for controlled items
- FIFO/LIFO rules followed for cost calculation
- Issue date cannot be future-dated
- Authorization required for high-value issues

---

#### TransferStock Command
**Purpose**: Transfers inventory between warehouse locations.

**Description**: Processes inventory transfer including source validation, destination preparation, in-transit tracking, and cost adjustments. Coordinates multi-location inventory movements.

**Parameters**:
- `transfer_id`: Unique transfer identifier
- `item_id`: Item being transferred
- `from_location_id`: Source warehouse location
- `to_location_id`: Destination warehouse location
- `quantity`: Quantity being transferred
- `transfer_reason`: Business reason for transfer
- `transfer_cost`: Cost of transfer if applicable
- `lot_serial_tracking`: Lot/serial numbers being transferred

**Business Rules**:
- Source location must have sufficient available inventory
- Destination location must be valid and active
- Transfer between different companies requires approval
- High-value transfers require authorization
- In-transit tracking required for long-distance transfers

---

#### AdjustStock Command
**Purpose**: Adjusts inventory quantities for corrections or physical count variances.

**Description**: Processes inventory adjustments including reason validation, authorization checking, cost impact calculation, and GL posting coordination. Maintains adjustment audit trail.

**Parameters**:
- `adjustment_id`: Unique adjustment identifier
- `item_id`: Item being adjusted
- `location_id`: Warehouse location for adjustment
- `adjustment_quantity`: Quantity adjustment (positive or negative)
- `adjustment_reason`: Coded reason for adjustment
- `unit_cost`: Cost basis for adjustment value
- `adjusted_by`: User making adjustment
- `approval_reference`: Approval documentation if required

**Business Rules**:
- Adjustment reason must be valid and coded
- Negative adjustments cannot exceed available quantity
- High-value adjustments require approval
- GL posting accounts must be properly configured
- Complete audit trail required for all adjustments

---

### Stock Movement Events

#### StockReceived Event
**Purpose**: Records successful inventory receipt transaction.

**Description**: Emitted when inventory is successfully received into warehouse. Contains receipt details and triggers balance updates, cost calculations, and integration processes.

**Data**:
- `transaction_id`: Receipt transaction identifier
- `item_id`: Item received
- `location_id`: Warehouse location
- `quantity`: Quantity received
- `unit_cost`: Cost per unit
- `total_cost`: Total receipt value
- `lot_number`: Lot assignment if applicable
- `serial_numbers`: Serial assignments if applicable
- `received_at`: Receipt timestamp

**Downstream Effects**:
- Updates warehouse inventory balances
- Updates item costing calculations
- Triggers available-to-promise calculations
- Updates procurement and planning systems

---

#### StockIssued Event
**Purpose**: Records successful inventory issue transaction.

**Description**: Emitted when inventory is issued from warehouse. Contains issue details and triggers balance updates, cost of goods sold calculations, and consumption tracking.

**Data**:
- `transaction_id`: Issue transaction identifier
- `item_id`: Item issued
- `location_id`: Source warehouse location
- `quantity`: Quantity issued
- `cost_of_goods_sold`: COGS amount calculated
- `lot_number`: Lot consumed if applicable
- `serial_numbers`: Serials consumed if applicable
- `issued_at`: Issue timestamp

**Downstream Effects**:
- Reduces warehouse inventory balances
- Updates cost of goods sold calculations
- Updates lot/serial genealogy tracking
- Triggers reorder point monitoring

---

#### StockTransferred Event
**Purpose**: Records inventory transfer between locations.

**Description**: Emitted when inventory transfer is initiated. Contains transfer details and triggers in-transit tracking, location updates, and cost adjustments.

**Data**:
- `transfer_id`: Transfer transaction identifier
- `item_id`: Item transferred
- `from_location_id`: Source location
- `to_location_id`: Destination location
- `quantity`: Quantity transferred
- `transfer_cost`: Transfer cost if applicable
- `in_transit_reference`: Tracking reference for transfer
- `initiated_at`: Transfer initiation timestamp

**Downstream Effects**:
- Creates in-transit inventory tracking
- Updates source location availability
- Sets up destination receipt processing
- Triggers cost adjustment calculations

---

#### StockAdjusted Event
**Purpose**: Records inventory quantity or value adjustments.

**Description**: Emitted when inventory adjustment is processed. Contains adjustment details and triggers balance updates, GL postings, and audit documentation.

**Data**:
- `adjustment_id`: Adjustment transaction identifier
- `item_id`: Item adjusted
- `location_id`: Warehouse location
- `previous_quantity`: Quantity before adjustment
- `new_quantity`: Quantity after adjustment
- `adjustment_value`: Financial impact of adjustment
- `reason_code`: Coded reason for adjustment
- `adjusted_at`: Adjustment timestamp

**Downstream Effects**:
- Updates warehouse inventory balances
- Creates GL postings for financial impact
- Updates inventory valuation calculations
- Creates adjustment audit trail

---

## Physical Count Commands and Events

### Count Processing

#### InitiatePhysicalCount Command
**Purpose**: Initiates physical inventory count process.

**Description**: Begins physical count including scope definition, item identification, counter assignment, and count coordination. Freezes transactions for counted areas during count execution.

**Parameters**:
- `count_id`: Unique count identifier
- `location_id`: Warehouse location being counted
- `count_type`: Type of count (full, cycle, spot)
- `count_scope`: Items included in count
- `expected_items`: Items expected to be found
- `counter_assignments`: Counter assignments for count
- `count_date`: Date of physical count

**Business Rules**:
- Count scope must be clearly defined
- Counters must be authorized and trained
- Transaction freeze applied to count areas
- Count date must be reasonable for business operations

---

#### RecordCountedQuantity Command
**Purpose**: Records counted quantities during physical inventory.

**Description**: Captures actual counted quantities including counter validation, variance detection, and count documentation. Supports multiple count rounds and blind counting procedures.

**Parameters**:
- `count_record_id`: Count record identifier
- `count_id`: Parent count process
- `item_id`: Item being counted
- `counted_quantity`: Actual quantity found
- `bin_location`: Specific bin location counted
- `counter_id`: Person performing count
- `count_timestamp`: When count was performed
- `count_round`: First count, recount, etc.

**Business Rules**:
- Counter must be authorized for count area
- Count quantities must be reasonable
- Blind counting procedures followed for accuracy
- Count documentation required for audit

---

#### FinalizeCount Command
**Purpose**: Finalizes physical count with variance analysis and adjustment processing.

**Description**: Completes physical count including variance calculation, tolerance checking, adjustment generation, and count documentation. Handles recount requirements and supervisor approval.

**Parameters**:
- `count_id`: Count to finalize
- `variance_analysis`: Calculated variances by item
- `adjustment_approvals`: Approved adjustments for posting
- `recount_requirements`: Items requiring recount
- `supervisor_sign_off`: Supervisor approval for count
- `finalized_by`: User finalizing count

**Business Rules**:
- All count variances must be analyzed
- Variances outside tolerance require recount
- Supervisor approval required for significant variances
- All adjustments require proper authorization

---

### Count Events

#### PhysicalCountStarted Event
**Purpose**: Records initiation of physical inventory count.

**Description**: Emitted when physical count process begins. Contains count scope and triggers transaction restrictions and count coordination activities.

**Data**:
- `count_id`: Started count identifier
- `location_id`: Warehouse location being counted
- `count_type`: Type of count being performed
- `expected_items`: Items expected to be counted
- `counter_assignments`: Assigned counters
- `freeze_timestamp`: When transaction freeze began
- `started_by`: User initiating count

**Downstream Effects**:
- Freezes transactions in count areas
- Initializes count tracking and coordination
- Sets up count validation and monitoring
- Creates count audit trail

---

#### ItemCounted Event
**Purpose**: Records individual item count results.

**Description**: Emitted when item is counted during physical inventory. Contains count details and triggers variance analysis and validation processes.

**Data**:
- `count_record_id`: Individual count record
- `count_id`: Parent count process
- `item_id`: Item that was counted
- `system_quantity`: Expected quantity per system
- `counted_quantity`: Actual quantity found
- `variance`: Difference between expected and counted
- `bin_location`: Specific location counted
- `counted_by`: Counter performing count

**Downstream Effects**:
- Updates count progress tracking
- Triggers variance analysis if difference exists
- Updates count validation processes
- Creates detailed count audit trail

---

#### CountVarianceDetected Event
**Purpose**: Records detection of count variance requiring attention.

**Description**: Emitted when count variance exceeds tolerance limits. Contains variance details and triggers recount procedures or approval workflows.

**Data**:
- `variance_id`: Variance detection identifier
- `count_id`: Related count process
- `item_id`: Item with variance
- `variance_quantity`: Quantity variance amount
- `variance_value`: Financial impact of variance
- `tolerance_exceeded`: How much tolerance was exceeded
- `recount_required`: Whether recount is needed

**Downstream Effects**:
- Triggers recount procedures if variance significant
- Routes to approval workflow for resolution
- Updates variance tracking and analysis
- Creates variance investigation documentation

---

#### CountCompleted Event
**Purpose**: Records completion of physical count process.

**Description**: Emitted when physical count completes with all variances resolved. Contains count summary and triggers final adjustment processing and audit documentation.

**Data**:
- `count_id`: Completed count identifier
- `total_items_counted`: Number of items counted
- `total_variance_value`: Net financial variance
- `adjustment_entries`: Generated adjustment transactions
- `count_accuracy`: Overall count accuracy metrics
- `completed_at`: Count completion timestamp

**Downstream Effects**:
- Processes final inventory adjustments
- Restores normal transaction processing
- Updates inventory accuracy metrics
- Creates final count audit documentation

---

## Transfer Management Commands and Events

### Transfer Processing

#### InitiateTransfer Command
**Purpose**: Initiates inventory transfer between warehouse locations.

**Description**: Begins transfer process including source validation, destination preparation, authorization checking, and transfer documentation. Sets up in-transit tracking and coordination.

**Parameters**:
- `transfer_id`: Unique transfer identifier
- `item_id`: Item being transferred
- `from_location_id`: Source warehouse
- `to_location_id`: Destination warehouse
- `transfer_quantity`: Quantity to transfer
- `transfer_reason`: Business justification
- `requested_by`: User requesting transfer
- `priority_level`: Transfer priority (normal, urgent, critical)

**Business Rules**:
- Source location must have sufficient available inventory
- Destination location must be valid and active
- Transfer quantity must be positive
- High-value transfers require authorization
- Cross-company transfers need special approval

---

#### ApproveTransfer Command
**Purpose**: Approves transfer request for execution.

**Description**: Authorizes transfer execution including final validation, resource allocation, shipping coordination, and tracking setup. Enables transfer processing and shipment.

**Parameters**:
- `transfer_id`: Transfer to approve
- `approved_by`: User providing approval
- `approval_conditions`: Any special conditions
- `shipping_method`: Method for transfer shipment
- `expected_receipt_date`: Expected delivery date
- `tracking_requirements`: Tracking and monitoring needs

**Business Rules**:
- Approval authority must be sufficient for transfer value
- All transfer validations must pass
- Shipping method must be appropriate for items
- Tracking requirements based on transfer value and distance

---

#### ReceiveTransfer Command
**Purpose**: Receives transferred inventory at destination location.

**Description**: Processes transfer receipt including quantity verification, condition inspection, variance handling, and final placement. Completes transfer lifecycle and updates balances.

**Parameters**:
- `transfer_id`: Transfer being received
- `received_quantity`: Actual quantity received
- `receipt_condition`: Condition of received items
- `variance_details`: Any quantity or condition variances
- `bin_placement`: Final bin location for items
- `received_by`: User processing receipt
- `receipt_date`: Date of receipt

**Business Rules**:
- Received quantity cannot exceed transferred quantity
- Condition variances must be documented
- Bin placement must follow warehouse rules
- Receipt date must be after transfer shipment date

---

### Transfer Events

#### TransferInitiated Event
**Purpose**: Records initiation of inventory transfer.

**Description**: Emitted when transfer process begins. Contains transfer details and triggers reservation, shipment preparation, and tracking activities.

**Data**:
- `transfer_id`: Transfer identifier
- `item_id`: Item being transferred
- `from_location_id`: Source location
- `to_location_id`: Destination location
- `transfer_quantity`: Quantity being transferred
- `transfer_reason`: Business justification
- `initiated_at`: Transfer initiation timestamp

**Downstream Effects**:
- Reserves inventory at source location
- Sets up in-transit tracking
- Triggers shipment preparation
- Updates transfer status projections

---

#### TransferShipped Event
**Purpose**: Records shipment of transfer from source location.

**Description**: Emitted when transfer is shipped from source. Contains shipment details and triggers in-transit tracking and destination preparation.

**Data**:
- `transfer_id`: Transfer being shipped
- `shipment_reference`: Shipping tracking reference
- `shipped_quantity`: Actual quantity shipped
- `shipping_method`: Method used for shipment
- `expected_delivery`: Expected delivery date
- `shipped_at`: Shipment timestamp

**Downstream Effects**:
- Reduces inventory at source location
- Creates in-transit inventory tracking
- Triggers destination preparation
- Updates transfer tracking projections

---

#### TransferReceived Event
**Purpose**: Records receipt of transfer at destination location.

**Description**: Emitted when transfer is received at destination. Contains receipt details and triggers balance updates, variance processing, and transfer completion.

**Data**:
- `transfer_id`: Transfer being received
- `received_quantity`: Quantity actually received
- `receipt_condition`: Condition assessment
- `variances`: Any quantity or condition variances
- `final_location`: Final placement location
- `received_at`: Receipt timestamp

**Downstream Effects**:
- Increases inventory at destination location
- Processes any transfer variances
- Completes transfer lifecycle
- Updates inventory projections at destination

---

## Kit Management Commands and Events

### Kit Processing

#### DefineKitComponents Command
**Purpose**: Defines component structure for kit items.

**Description**: Establishes kit component relationships including component selection, quantity requirements, substitution rules, and assembly instructions. Creates foundation for kit operations.

**Parameters**:
- `kit_definition_id`: Kit definition identifier
- `kit_item_id`: Parent kit item
- `components`: List of component items and quantities
- `assembly_instructions`: How kit should be assembled
- `substitution_rules`: Acceptable component substitutes
- `effective_date`: When kit definition becomes active

**Business Rules**:
- All component items must exist and be active
- Component quantities must be positive
- Kit cannot be component of itself (circular reference prevention)
- Assembly instructions must be clear and complete

---

#### ExplodeKitComponents Command
**Purpose**: Explodes kit requirements into individual component needs.

**Description**: Breaks down kit requirements into component-level needs including quantity calculation, availability checking, and allocation preparation for kit fulfillment.

**Parameters**:
- `explosion_id`: Kit explosion identifier
- `kit_item_id`: Kit being exploded
- `required_quantity`: Number of kits needed
- `explosion_date`: Date for explosion calculation
- `location_preferences`: Preferred fulfillment locations
- `substitution_allowed`: Whether substitutes acceptable

**Business Rules**:
- Kit definition must be active and complete
- Component requirements calculated using current ratios
- Availability checked across specified locations
- Substitution rules followed if shortages exist

---

#### AssembleKit Command
**Purpose**: Processes kit assembly including component consumption.

**Description**: Coordinates kit assembly including component consumption, assembly processing, and finished kit receipt. Handles assembly validation and quality requirements.

**Parameters**:
- `assembly_id`: Kit assembly identifier
- `kit_item_id`: Kit being assembled
- `assembly_quantity`: Number of kits to assemble
- `component_consumption`: Actual components used
- `assembly_location`: Where assembly performed
- `quality_control`: Quality requirements for assembly
- `assembled_by`: Person or process performing assembly

**Business Rules**:
- All required components must be available
- Assembly quantity must be achievable with available components
- Quality control requirements must be met
- Assembly processing must follow defined procedures

---

### Kit Events

#### KitComponentsDefined Event
**Purpose**: Records definition of kit component structure.

**Description**: Emitted when kit components are defined or updated. Contains component structure and triggers kit availability calculations and assembly capability setup.

**Data**:
- `kit_definition_id`: Kit definition identifier
- `kit_item_id`: Parent kit item
- `components`: Component structure with quantities
- `assembly_method`: How kit should be assembled
- `substitution_rules`: Acceptable substitutions
- `effective_date`: When definition becomes active

**Downstream Effects**:
- Enables kit availability calculations
- Sets up component requirement tracking
- Triggers assembly capability validation
- Updates kit costing calculations

---

#### KitExploded Event
**Purpose**: Records explosion of kit into component requirements.

**Description**: Emitted when kit is exploded into component needs. Contains explosion details and triggers component allocation and availability processes.

**Data**:
- `explosion_id`: Kit explosion identifier
- `kit_item_id`: Kit that was exploded
- `required_quantity`: Kit quantity needed
- `component_requirements`: Component needs calculated
- `availability_status`: Component availability results
- `substitutions_needed`: Components requiring substitution

**Downstream Effects**:
- Triggers component availability checking
- Initiates component allocation processes
- Updates kit fulfillment projections
- Sets up assembly coordination

---

#### KitAssembled Event
**Purpose**: Records completion of kit assembly process.

**Description**: Emitted when kit assembly completes successfully. Contains assembly results and triggers inventory updates and quality validation.

**Data**:
- `assembly_id`: Kit assembly identifier
- `kit_item_id`: Kit that was assembled
- `assembled_quantity`: Number of kits completed
- `components_consumed`: Actual component consumption
- `assembly_cost`: Total assembly cost
- `quality_results`: Quality control results
- `assembled_at`: Assembly completion timestamp

**Downstream Effects**:
- Increases kit inventory quantities
- Reduces component inventory quantities
- Updates assembly cost calculations
- Triggers quality validation if required

---

## Lot and Serial Control Commands and Events

### Lot Management

#### CreateLot Command
**Purpose**: Creates new lot for lot-controlled inventory items.

**Description**: Establishes new inventory lot including lot number assignment, expiration date setting, quality status initialization, and tracking setup for lot-controlled items.

**Parameters**:
- `lot_id`: Unique lot identifier
- `item_id`: Item for lot creation
- `lot_number`: Lot number (auto-generated or manual)
- `creation_date`: Lot creation date
- `expiration_date`: Lot expiration date if applicable
- `initial_quantity`: Starting lot quantity
- `source_reference`: Source of lot (receipt, production, etc.)

**Business Rules**:
- Item must be lot-controlled
- Lot number must be unique for item
- Expiration date required for perishable items
- Initial quantity must match source transaction

---

#### UpdateLotStatus Command
**Purpose**: Updates lot status for quality and availability management.

**Description**: Changes lot status including quality hold, release, quarantine, and expiration management. Coordinates lot status with inventory availability and quality processes.

**Parameters**:
- `lot_id`: Lot to update
- `new_status`: Updated lot status
- `status_reason`: Reason for status change
- `effective_date`: When status change becomes effective
- `quality_data`: Quality test results if applicable
- `updated_by`: User authorizing status change

**Business Rules**:
- Status changes must follow defined workflow
- Quality holds require quality data
- Expired lots cannot be released without retest
- Status change authorization required

---

#### AssignSerialNumber Command
**Purpose**: Assigns serial numbers to serialized inventory items.

**Description**: Assigns unique serial numbers including validation, tracking setup, and genealogy initialization for complete traceability through item lifecycle.

**Parameters**:
- `serial_assignment_id`: Serial assignment identifier
- `item_id`: Item receiving serial numbers
- `serial_numbers`: Serial numbers being assigned
- `assignment_source`: Source of assignment (receipt, production)
- `location_id`: Initial location for serialized items
- `assigned_by`: User or process assigning serials

**Business Rules**:
- Item must be serial-controlled
- Serial numbers must be unique globally
- Serial format must follow configured pattern
- Assignment source must be valid transaction

---

### Lot and Serial Events

#### LotCreated Event
**Purpose**: Records creation of new inventory lot.

**Description**: Emitted when new lot is created for lot-controlled item. Contains lot details and triggers lot tracking and availability processes.

**Data**:
- `lot_id`: Created lot identifier
- `item_id`: Item for lot
- `lot_number`: Assigned lot number
- `creation_date`: Lot creation date
- `expiration_date`: Lot expiration if applicable
- `initial_quantity`: Starting quantity
- `quality_status`: Initial quality status

**Downstream Effects**:
- Sets up lot tracking and monitoring
- Enables lot-based inventory transactions
- Triggers expiration monitoring if applicable
- Creates lot genealogy tracking

---

#### SerialNumberAssigned Event
**Purpose**: Records assignment of serial numbers to items.

**Description**: Emitted when serial numbers are assigned to serialized items. Contains serial details and triggers individual item tracking and genealogy processes.

**Data**:
- `serial_assignment_id`: Assignment identifier
- `item_id`: Item receiving serials
- `serial_numbers`: Assigned serial numbers
- `assignment_location`: Initial location
- `assignment_source`: Source transaction
- `assigned_at`: Assignment timestamp

**Downstream Effects**:
- Enables individual item tracking
- Sets up serial genealogy tracking
- Triggers warranty and service tracking
- Creates serial audit trail

---

## Pricing Management Commands and Events

### Price Management

#### SetBasePrice Command
**Purpose**: Sets base pricing for inventory items.

**Description**: Establishes base item pricing including price validation, effective date management, and margin checking. Forms foundation for pricing hierarchy and customer pricing.

**Parameters**:
- `pricing_id`: Price setting identifier
- `item_id`: Item receiving price
- `base_price`: Base selling price
- `cost_basis`: Cost basis for margin calculation
- `effective_date`: When price becomes effective
- `price_approval`: Approval for pricing if required
- `margin_analysis`: Margin calculation and validation

**Business Rules**:
- Base price must be positive
- Margin must meet minimum requirements
- Price changes require appropriate approval
- Effective dates must be logical

---

#### ConfigureVolumeDiscounts Command
**Purpose**: Configures volume-based pricing tiers for items.

**Description**: Sets up volume discount structure including quantity breaks, discount percentages, and tier management. Enables sophisticated pricing based on order quantities.

**Parameters**:
- `discount_config_id`: Volume discount configuration
- `item_id`: Item for volume pricing
- `quantity_breaks`: Quantity thresholds and prices
- `discount_method`: Percentage or fixed amount discounts
- `tier_structure`: Pricing tier organization
- `effective_period`: When volume pricing is active

**Business Rules**:
- Quantity breaks must be in ascending order
- Discount percentages must be reasonable
- Tier structure must be mathematically consistent
- Volume pricing authorization required

---

#### SetCustomerPrice Command
**Purpose**: Sets customer-specific pricing overrides.

**Description**: Establishes customer-specific pricing including contract pricing, special agreements, and customer tier pricing. Manages customer pricing hierarchy and approval requirements.

**Parameters**:
- `customer_pricing_id`: Customer price identifier
- `item_id`: Item for customer pricing
- `customer_id`: Customer receiving special pricing
- `customer_price`: Special price for customer
- `pricing_basis`: Basis for special pricing
- `contract_reference`: Contract supporting pricing
- `effective_period`: Period for special pricing

**Business Rules**:
- Customer must be active and approved
- Special pricing must be justified and approved
- Contract pricing must have valid contract reference
- Pricing effective periods must be reasonable

---

### Pricing Events

#### BasePriceSet Event
**Purpose**: Records establishment of base item pricing.

**Description**: Emitted when base price is set for item. Contains pricing details and triggers pricing hierarchy updates and margin validation processes.

**Data**:
- `pricing_id`: Price setting identifier
- `item_id`: Item with new pricing
- `base_price`: Established base price
- `cost_basis`: Cost used for margin calculation
- `margin_percentage`: Calculated margin
- `effective_date`: Price effective date
- `set_by`: User setting price

**Downstream Effects**:
- Updates item pricing projections
- Triggers margin analysis and alerts
- Updates customer pricing calculations
- Creates pricing audit trail

---

#### VolumeDiscountsConfigured Event
**Purpose**: Records configuration of volume-based pricing.

**Description**: Emitted when volume discount structure is configured. Contains discount details and triggers volume pricing calculations and customer pricing updates.

**Data**:
- `discount_config_id`: Volume discount configuration
- `item_id`: Item with volume pricing
- `quantity_tiers`: Configured quantity breaks
- `discount_structure`: Discount percentages or amounts
- `pricing_method`: How discounts are calculated
- `configured_at`: Configuration timestamp

**Downstream Effects**:
- Enables volume-based pricing calculations
- Updates customer pricing options
- Triggers pricing validation and testing
- Creates volume pricing audit trail

---

## Costing and Valuation Commands and Events

### Cost Management

#### CalculateItemCost Command
**Purpose**: Calculates item cost using configured costing method.

**Description**: Performs cost calculation including method-specific logic (FIFO, LIFO, average, standard), cost layer management, and variance analysis. Maintains cost accuracy and audit trails.

**Parameters**:
- `cost_calculation_id`: Cost calculation identifier
- `item_id`: Item for cost calculation
- `calculation_method`: Costing method to apply
- `transaction_context`: Transaction triggering calculation
- `cost_layers`: Available cost layers for calculation
- `calculation_date`: Date for cost calculation

**Business Rules**:
- Costing method must match item configuration
- Cost layers must be available for FIFO/LIFO
- Standard costs must be current and approved
- Cost calculations must be mathematically accurate

---

#### UpdateStandardCost Command
**Purpose**: Updates standard cost for items using standard costing.

**Description**: Establishes or revises standard costs including cost validation, variance impact analysis, and effective date management. Coordinates standard cost updates across locations.

**Parameters**:
- `standard_cost_id`: Standard cost update identifier
- `item_id`: Item for standard cost update
- `new_standard_cost`: Updated standard cost
- `cost_effective_date`: When new cost becomes effective
- `variance_impact`: Impact on existing inventory
- `approval_reference`: Approval for cost change
- `cost_justification`: Business justification for change

**Business Rules**:
- Standard cost changes require financial approval
- Cost effective dates must be period boundaries
- Variance impact must be calculated and approved
- Cost justification required for significant changes

---

#### ProcessCostVariance Command
**Purpose**: Processes cost variances from standard cost differences.

**Description**: Handles cost variances including variance calculation, classification, GL posting, and management reporting. Provides cost variance analysis and corrective action coordination.

**Parameters**:
- `variance_id`: Cost variance identifier
- `item_id`: Item with cost variance
- `variance_type`: Type of variance (price, usage, efficiency)
- `variance_amount`: Amount of variance
- `variance_reason`: Reason for variance occurrence
- `gl_posting_accounts`: Accounts for variance posting
- `corrective_actions`: Recommended corrective actions

**Business Rules**:
- Variance calculations must be accurate
- Variance classification must follow accounting standards
- GL posting accounts must be valid
- Significant variances require investigation

---

### Cost Events

#### ItemCostCalculated Event
**Purpose**: Records completion of item cost calculation.

**Description**: Emitted when item cost calculation completes. Contains cost details and triggers cost-dependent processes and GL integration.

**Data**:
- `cost_calculation_id`: Calculation identifier
- `item_id`: Item with calculated cost
- `calculated_cost`: Resulting unit cost
- `calculation_method`: Method used for calculation
- `cost_components`: Breakdown of cost elements
- `calculation_date`: When calculation performed
- `calculated_by`: User or system performing calculation

**Downstream Effects**:
- Updates item cost projections and valuations
- Triggers cost-based pricing updates
- Updates inventory valuation calculations
- Creates cost calculation audit trail

---

#### StandardCostUpdated Event
**Purpose**: Records standard cost updates for items.

**Description**: Emitted when standard cost is updated. Contains cost change details and triggers variance calculations and inventory revaluation processes.

**Data**:
- `standard_cost_id`: Standard cost update identifier
- `item_id`: Item with cost update
- `previous_cost`: Former standard cost
- `new_cost`: Updated standard cost
- `cost_variance_impact`: Impact on existing inventory
- `effective_date`: Cost effective date
- `updated_by`: User authorizing update

**Downstream Effects**:
- Updates standard cost across all locations
- Triggers inventory revaluation processes
- Calculates cost variance impact
- Updates cost variance monitoring

---

## Warehouse Management Commands and Events

### Warehouse Operations

#### CreateWarehouse Command
**Purpose**: Creates new warehouse location for inventory operations.

**Description**: Establishes new warehouse including location setup, configuration parameters, bin structure definition, and operational settings. Initializes warehouse for inventory management.

**Parameters**:
- `warehouse_id`: Unique warehouse identifier
- `warehouse_code`: Warehouse code for identification
- `description`: Warehouse description
- `address_information`: Physical address details
- `operational_parameters`: Operating hours, capacity, etc.
- `bin_structure`: Bin layout and organization
- `gl_account_mapping`: GL accounts for warehouse transactions

**Business Rules**:
- Warehouse code must be unique
- Address information complete for shipping/receiving
- GL account mappings must be valid
- Operational parameters must be reasonable

---

#### UpdateWarehouseConfig Command
**Purpose**: Updates warehouse configuration and operational parameters.

**Description**: Modifies warehouse settings including operational parameters, capacity constraints, bin structure, and integration settings. Maintains warehouse operational efficiency.

**Parameters**:
- `warehouse_id`: Warehouse to update
- `configuration_changes`: Updated configuration parameters
- `capacity_adjustments`: Capacity constraint changes
- `bin_modifications`: Bin structure updates
- `operational_updates`: Operating parameter changes
- `updated_by`: User making changes

**Business Rules**:
- Configuration changes must not disrupt operations
- Capacity adjustments must be realistic
- Bin modifications must maintain inventory integrity
- Operational updates require appropriate authorization

---

#### ConfigureBinStructure Command
**Purpose**: Configures bin layout and organization within warehouse.

**Description**: Sets up warehouse bin structure including zone definition, aisle layout, capacity constraints, and picking optimization. Enables efficient warehouse operations.

**Parameters**:
- `bin_config_id`: Bin configuration identifier
- `warehouse_id`: Warehouse being configured
- `zone_structure`: Zone layout and organization
- `bin_naming_convention`: Bin identification system
- `capacity_constraints`: Bin capacity limits
- `picking_optimization`: Picking sequence optimization
- `putaway_strategy`: Putaway location strategy

**Business Rules**:
- Bin naming must be unique within warehouse
- Capacity constraints must be realistic
- Picking optimization must consider operational flow
- Putaway strategy must be efficient and safe

---

### Warehouse Events

#### WarehouseCreated Event
**Purpose**: Records creation of new warehouse location.

**Description**: Emitted when warehouse is successfully created. Contains warehouse details and triggers initialization of warehouse operations and inventory tracking.

**Data**:
- `warehouse_id`: Created warehouse identifier
- `warehouse_code`: Assigned warehouse code
- `description`: Warehouse description
- `operational_parameters`: Operating configuration
- `bin_structure`: Initial bin layout
- `created_by`: User creating warehouse

**Downstream Effects**:
- Initializes warehouse inventory tracking
- Sets up warehouse operational projections
- Enables inventory transactions at location
- Creates warehouse audit trail

---

#### BinStructureConfigured Event
**Purpose**: Records configuration of warehouse bin structure.

**Description**: Emitted when bin structure is configured or updated. Contains bin layout details and triggers picking optimization and capacity management processes.

**Data**:
- `bin_config_id`: Bin configuration identifier
- `warehouse_id`: Warehouse with bin structure
- `zone_layout`: Configured zone structure
- `bin_count`: Total number of bins configured
- `capacity_summary`: Total capacity by zone
- `optimization_settings`: Picking and putaway optimization
- `configured_at`: Configuration timestamp

**Downstream Effects**:
- Enables bin-level inventory tracking
- Sets up picking and putaway optimization
- Initializes capacity monitoring
- Creates bin configuration audit trail

---

## Planning and Analytics Commands and Events

### Demand Planning

#### GenerateForecast Command
**Purpose**: Generates demand forecast for inventory planning.

**Description**: Creates demand forecast including historical analysis, trend identification, seasonal adjustment, and statistical modeling for inventory planning and procurement optimization.

**Parameters**:
- `forecast_id`: Forecast generation identifier
- `item_scope`: Items included in forecast
- `forecast_horizon`: Planning horizon for forecast
- `forecast_method`: Statistical method for forecasting
- `historical_data`: Historical demand data for analysis
- `seasonal_factors`: Seasonal adjustment factors
- `external_factors`: External factors affecting demand

**Business Rules**:
- Forecast horizon must be reasonable for business
- Historical data must be sufficient for accuracy
- Forecast methods must be appropriate for data
- External factors must be quantifiable

---

#### OptimizePlanningParameters Command
**Purpose**: Optimizes inventory planning parameters for efficiency.

**Description**: Analyzes and optimizes planning parameters including reorder points, safety stock levels, order quantities, and lead times for optimal inventory performance.

**Parameters**:
- `optimization_id`: Optimization process identifier
- `item_scope`: Items included in optimization
- `optimization_criteria`: Criteria for optimization (cost, service level)
- `constraint_parameters`: Business constraints for optimization
- `performance_targets`: Target performance metrics
- `optimization_method`: Mathematical approach for optimization

**Business Rules**:
- Optimization criteria must be clearly defined
- Constraints must be realistic and achievable
- Performance targets must be measurable
- Optimization results require validation

---

### Planning Events

#### ForecastGenerated Event
**Purpose**: Records completion of demand forecast generation.

**Description**: Emitted when demand forecast is completed. Contains forecast results and triggers planning parameter updates and procurement coordination.

**Data**:
- `forecast_id`: Generated forecast identifier
- `item_forecasts`: Forecast by item and period
- `forecast_accuracy`: Accuracy metrics from previous forecasts
- `trend_analysis`: Identified trends and patterns
- `forecast_method`: Method used for generation
- `generated_at`: Forecast generation timestamp

**Downstream Effects**:
- Updates demand planning parameters
- Triggers procurement requirement calculations
- Updates safety stock and reorder point calculations
- Creates forecast accuracy tracking

---

#### PlanningParametersOptimized Event
**Purpose**: Records optimization of inventory planning parameters.

**Description**: Emitted when planning parameter optimization completes. Contains optimized parameters and triggers implementation of improved planning settings.

**Data**:
- `optimization_id`: Optimization process identifier
- `optimized_parameters`: Optimized planning parameters by item
- `performance_improvement`: Expected performance gains
- `optimization_method`: Method used for optimization
- `implementation_plan`: Plan for implementing changes
- `optimized_at`: Optimization completion timestamp

**Downstream Effects**:
- Updates inventory planning parameters
- Triggers performance monitoring setup
- Updates procurement and replenishment processes
- Creates optimization audit trail

---

## Quality Control Commands and Events

### Quality Management

#### ScheduleInspection Command
**Purpose**: Schedules quality inspection for inventory items.

**Description**: Creates quality inspection schedule including inspection planning, resource allocation, test specification, and compliance coordination for quality-controlled items.

**Parameters**:
- `inspection_id`: Quality inspection identifier
- `item_id`: Item requiring inspection
- `inspection_type`: Type of inspection (incoming, process, final)
- `test_specifications`: Tests to be performed
- `sampling_plan`: Sampling methodology
- `inspection_schedule`: When inspection should occur
- `inspector_assignment`: Assigned quality inspector

**Business Rules**:
- Item must require quality inspection
- Test specifications must be current and approved
- Sampling plan must follow statistical requirements
- Inspector must be qualified for test type

---

#### RecordTestResults Command
**Purpose**: Records quality test results and disposition decisions.

**Description**: Captures quality test results including test data, pass/fail determination, disposition decisions, and corrective action requirements for quality-controlled inventory.

**Parameters**:
- `test_result_id`: Test result identifier
- `inspection_id`: Related quality inspection
- `test_data`: Actual test measurements and observations
- `test_evaluation`: Pass/fail determination
- `disposition`: Accept, reject, or conditional acceptance
- `corrective_actions`: Required corrective actions if any
- `tested_by`: Quality inspector performing tests

**Business Rules**:
- Test data must be complete and accurate
- Test evaluation must follow approved criteria
- Disposition must be appropriate for test results
- Corrective actions required for failures

---

### Quality Events

#### InspectionScheduled Event
**Purpose**: Records scheduling of quality inspection.

**Description**: Emitted when quality inspection is scheduled. Contains inspection details and triggers inspection preparation and resource allocation.

**Data**:
- `inspection_id`: Scheduled inspection identifier
- `item_id`: Item for inspection
- `inspection_type`: Type of inspection
- `scheduled_date`: When inspection scheduled
- `inspector_assigned`: Assigned quality inspector
- `test_requirements`: Tests to be performed

**Downstream Effects**:
- Sets up inspection tracking and monitoring
- Allocates inspection resources
- Triggers test preparation activities
- Creates inspection audit trail

---

#### TestResultsRecorded Event
**Purpose**: Records completion of quality testing with results.

**Description**: Emitted when quality tests are completed with results. Contains test data and triggers disposition processing and quality status updates.

**Data**:
- `test_result_id`: Test result identifier
- `inspection_id`: Related inspection
- `test_results`: Complete test data and measurements
- `disposition`: Quality disposition (accept/reject/conditional)
- `quality_status`: Updated quality status
- `corrective_actions`: Required actions if applicable
- `tested_at`: Test completion timestamp

**Downstream Effects**:
- Updates item quality status
- Triggers disposition processing (release/hold/reject)
- Updates quality metrics and reporting
- Creates quality test audit trail

---

## Summary

The Inventory Control domain contains **25 primary command types** and **20 primary event types** organized into:

**Item Management**: Item creation, specification updates, activation/deactivation commands with item lifecycle events
**Stock Movement**: Receipt, issue, transfer, and adjustment commands with movement tracking events
**Physical Count**: Count initiation, recording, and finalization commands with count process events
**Transfer Management**: Transfer initiation, approval, and receipt commands with transfer lifecycle events
**Kit Management**: Kit definition, explosion, and assembly commands with kit processing events
**Lot/Serial Control**: Lot creation, serial assignment, and status management commands with traceability events
**Pricing Management**: Base pricing, volume discounts, and customer pricing commands with pricing lifecycle events
**Cost Management**: Cost calculation, standard cost updates, and variance processing commands with costing events
**Warehouse Management**: Warehouse creation, configuration, and bin structure commands with warehouse events
**Quality Control**: Inspection scheduling and test result recording commands with quality process events
**Planning Operations**: Forecast generation and parameter optimization commands with planning events

Each command includes detailed parameters, business rules, and validation requirements, while events provide comprehensive data about system state changes and trigger appropriate downstream processing. The design supports complex inventory management scenarios including multi-location tracking, sophisticated costing methods (FIFO, LIFO, Average, Standard), lot/serial traceability, kit management, quality control processes, and comprehensive planning capabilities while maintaining data integrity, audit compliance, and seamless integration with other Accountex modules including Sales Orders, Manufacturing, Purchasing, and General Ledger.