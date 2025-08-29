# Accountex Sales Orders - Commands and Events

## Overview

This document provides a comprehensive list of all commands and events in the Sales Orders domain. Commands represent requests to change system state, while events represent facts about what has happened in the system. The design follows CQRS (Command Query Responsibility Segregation) and Event Sourcing patterns using the Commanded framework.

## Order Management Commands and Events

### Order Lifecycle Management

#### CreateOrder Command
**Purpose**: Creates a new sales order in the system.

**Description**: Initiates sales order processing by capturing order data from customer including line items, addresses, payment terms, and shipping instructions. Validates customer credit and inventory availability before creating order.

**Parameters**:
- `order_id`: Unique identifier for the order
- `customer_id`: Customer placing the order
- `order_type`: Type of order (standard, blanket, recurring, drop_ship)
- `line_items`: List of ordered products with quantities and pricing
- `ship_to_address`: Delivery address information
- `bill_to_address`: Billing address information
- `payment_terms`: Payment method and terms
- `requested_ship_date`: Customer requested delivery date

**Business Rules**:
- Customer must be active and in good standing
- Credit check must pass based on order value
- All line items must have positive quantities
- Inventory availability validation for stock items
- Ship-to address required for physical products

---

#### ApproveOrder Command
**Purpose**: Approves an order for fulfillment processing.

**Description**: Records approval decision and advances order through approval workflow. Triggers inventory allocation and fulfillment planning based on approval level and order characteristics.

**Parameters**:
- `order_id`: Order to approve
- `approved_by`: User providing approval
- `approval_level`: Level of authority exercised
- `approval_conditions`: Any special conditions or notes
- `credit_override`: Credit limit override if applicable

**Business Rules**:
- Approver must have sufficient authority for order value
- Credit check must pass or have override authorization
- Cannot approve orders with inventory shortages unless backorders allowed
- Order must be in pending approval status

---

#### CancelOrder Command
**Purpose**: Cancels an order and handles compensation activities.

**Description**: Cancels order with appropriate reason coding and triggers compensation workflow including inventory release, payment processing, and customer notification.

**Parameters**:
- `order_id`: Order to cancel
- `cancellation_reason_code`: Coded reason for cancellation
- `cancellation_category`: Type of cancellation (customer, vendor, system)
- `detailed_explanation`: Additional explanation
- `cancelled_by`: User requesting cancellation
- `requires_approval`: Whether cancellation needs approval

**Business Rules**:
- Cannot cancel orders already shipped
- Cancellation authorization based on order value and status
- Inventory allocation must be released
- Payment processing implications handled

---

#### PlaceOrderOnHold Command
**Purpose**: Places order on hold with specific reason and resolution requirements.

**Description**: Suspends order processing for specified reasons including credit issues, inventory problems, or customer requests. Maintains order state while preventing further processing.

**Parameters**:
- `order_id`: Order to place on hold
- `hold_type`: Type of hold (credit, inventory, customer, quality)
- `hold_reason`: Specific reason for hold
- `expected_resolution`: Expected resolution approach
- `hold_expiry`: Automatic hold release date if applicable

**Business Rules**:
- Hold authority based on hold type and order value
- Credit holds require financial approval to release
- Inventory holds require inventory manager approval
- Automatic expiry handling for certain hold types

---

#### ReleaseOrderFromHold Command
**Purpose**: Releases order from hold status and resumes processing.

**Description**: Removes hold status and resumes order processing including re-validation of credit, inventory availability, and other prerequisites. May require re-approval depending on hold duration.

**Parameters**:
- `order_id`: Order to release from hold
- `release_reason`: Reason for release
- `released_by`: User authorizing release
- `revalidation_required`: Whether full revalidation needed
- `approval_reset`: Whether approval workflow should restart

**Business Rules**:
- Release authority must match or exceed hold authority
- Credit and inventory revalidation if hold was extended
- May require new approval if significant time elapsed
- All hold conditions must be resolved

---

### Order Events

#### OrderCreated Event
**Purpose**: Records creation of new sales order.

**Description**: Emitted when sales order is successfully created in the system. Contains complete order information and triggers downstream processing workflows including credit checking and inventory allocation.

**Data**:
- `order_id`: Created order identifier
- `customer_id`: Customer placing order
- `order_number`: System-assigned order number
- `total_amount`: Total order value
- `line_item_count`: Number of line items
- `created_by`: User creating order
- `created_at`: Creation timestamp

**Downstream Effects**:
- Triggers customer credit check workflow
- Initiates inventory availability checking
- Updates order pipeline projections
- Creates order audit trail entry

---

#### OrderApproved Event
**Purpose**: Records order approval and authorization for fulfillment.

**Description**: Emitted when order receives all required approvals and is authorized for fulfillment processing. Triggers inventory allocation and fulfillment planning activities.

**Data**:
- `order_id`: Approved order
- `approved_by`: Final approver
- `approval_level`: Authority level used
- `approved_at`: Approval timestamp
- `approval_conditions`: Any special conditions
- `credit_status`: Customer credit validation result

**Downstream Effects**:
- Authorizes inventory allocation
- Triggers fulfillment planning workflow
- Updates order status projections
- Enables shipment scheduling

---

#### OrderCancelled Event
**Purpose**: Records order cancellation with reason and impact analysis.

**Description**: Emitted when order is cancelled with complete impact analysis including lost revenue, inventory release, and compensation requirements. Triggers cleanup and notification workflows.

**Data**:
- `order_id`: Cancelled order
- `cancellation_reason_code`: Coded cancellation reason
- `cancelled_by`: User requesting cancellation
- `cancelled_at`: Cancellation timestamp
- `order_status_at_cancellation`: Status when cancelled
- `lost_revenue_amount`: Revenue impact

**Downstream Effects**:
- Releases allocated inventory
- Processes any required refunds
- Updates sales performance metrics
- Triggers customer communication

---

## Shipment and Fulfillment Commands and Events

### Shipment Processing

#### ShipOrder Command
**Purpose**: Creates shipment and initiates fulfillment process.

**Description**: Initiates order shipment including inventory allocation confirmation, pick list generation, packing optimization, and carrier selection. Handles partial shipments and special shipping requirements.

**Parameters**:
- `order_id`: Order to ship
- `warehouse_id`: Fulfillment warehouse
- `shipment_items`: Specific items and quantities to ship
- `carrier`: Selected shipping carrier
- `shipping_method`: Method of shipment
- `tracking_number`: Carrier tracking reference
- `picker_id`: Warehouse picker assignment
- `packer_id`: Warehouse packer assignment

**Business Rules**:
- Order must be approved and inventory allocated
- All shipped items must be available in specified warehouse
- Carrier and method must be valid for destination
- Partial shipments require customer approval if configured

---

#### CreatePartialShipment Command
**Purpose**: Creates partial shipment when full order cannot be fulfilled.

**Description**: Handles partial order fulfillment including item selection, backorder creation, and customer notification. Manages complex partial shipment scenarios with multiple shipments.

**Parameters**:
- `order_id`: Order for partial shipment
- `shipment_reason`: Reason for partial fulfillment
- `selected_items`: Items to include in shipment
- `warehouse_id`: Source warehouse
- `expected_remaining_shipments`: Number of additional shipments expected
- `customer_notified`: Customer notification status

**Business Rules**:
- Minimum shipment value thresholds
- Customer approval for partial shipments if required
- Backorder creation for remaining items
- Freight allocation across shipments

---

#### HandleOverShipment Command
**Purpose**: Manages over-shipment scenarios with resolution options.

**Description**: Handles cases where shipped quantity exceeds ordered quantity including resolution options, customer notification, and appropriate compensation or correction actions.

**Parameters**:
- `order_id`: Order with over-shipment
- `item_id`: Specific item over-shipped
- `excess_quantity`: Amount over-shipped
- `resolution_type`: How to resolve (customer keeps, return, credit)
- `manager_approval_id`: Required approval for resolution

**Business Rules**:
- Over-shipment threshold validation
- Customer agreement required for keeping excess
- Return processing for warehouse returns
- Credit memo generation for customer credits

---

#### ConfirmDelivery Command
**Purpose**: Confirms successful delivery to customer.

**Description**: Records delivery confirmation including delivery date, recipient information, and condition notes. Completes shipment lifecycle and triggers billing processes.

**Parameters**:
- `shipment_id`: Shipment being confirmed
- `delivery_date`: Actual delivery date
- `recipient_name`: Person receiving delivery
- `delivery_condition`: Condition notes (damaged, complete, etc.)
- `proof_of_delivery`: Delivery confirmation reference

**Business Rules**:
- Delivery date cannot be before ship date
- Recipient information required for high-value shipments
- Damage claims must be processed within timeframe
- Triggers automatic billing if configured

---

### Shipment Events

#### OrderShipped Event
**Purpose**: Records successful shipment of order or partial order.

**Description**: Emitted when order is successfully shipped including tracking information and delivery details. Triggers billing processes and customer notification workflows.

**Data**:
- `order_id`: Shipped order
- `shipment_id`: Generated shipment identifier
- `warehouse_id`: Source warehouse
- `shipped_items`: List of items and quantities shipped
- `tracking_number`: Carrier tracking reference
- `carrier`: Shipping carrier used
- `ship_date`: Actual ship date
- `expected_delivery`: Estimated delivery date

**Downstream Effects**:
- Triggers automatic invoice generation if configured
- Updates inventory quantities and allocations
- Initiates delivery tracking and monitoring
- Updates order fulfillment status projections

---

#### PartialShipmentCreated Event
**Purpose**: Records creation of partial shipment with backorder information.

**Description**: Emitted when partial shipment is created due to inventory constraints or other factors. Contains shipment details and backorder information for remaining items.

**Data**:
- `order_id`: Original order
- `shipment_id`: Partial shipment identifier
- `shipped_items`: Items included in shipment
- `remaining_items`: Items backordered
- `shipment_number`: Sequence number for this shipment
- `total_shipments_expected`: Expected total number of shipments

**Downstream Effects**:
- Creates backorder for remaining items
- Updates partial fulfillment tracking
- Triggers customer notification for partial delivery
- Updates inventory allocation for remaining items

---

#### DeliveryConfirmed Event
**Purpose**: Records confirmation of successful delivery to customer.

**Description**: Emitted when delivery is confirmed by customer or carrier. Completes shipment lifecycle and enables final billing and invoicing processes.

**Data**:
- `shipment_id`: Delivered shipment
- `delivery_date`: Confirmed delivery date
- `recipient_info`: Delivery recipient details
- `delivery_condition`: Condition and quality notes
- `proof_of_delivery`: Confirmation documentation

**Downstream Effects**:
- Completes shipment and order lifecycle
- Triggers final billing processes
- Updates delivery performance metrics
- Enables customer satisfaction tracking

---

## Quote Management Commands and Events

### Quote Processing

#### CreateQuote Command
**Purpose**: Creates a new sales quote for customer consideration.

**Description**: Initiates quote process including pricing calculation, terms proposal, and approval workflow. Handles complex pricing scenarios including volume discounts and special pricing.

**Parameters**:
- `quote_id`: Unique quote identifier
- `customer_id`: Customer requesting quote
- `quote_type`: Type of quote (standard, RFQ response, competitive)
- `line_items`: Products and services being quoted
- `pricing_strategy`: Approach for pricing calculation
- `validity_period`: How long quote remains valid
- `special_terms`: Any special conditions or terms

**Business Rules**:
- Customer must be active or qualified prospect
- All quoted items must be available or orderable
- Pricing must meet minimum margin requirements
- Quote validity period within policy limits

---

#### ApproveQuote Command
**Purpose**: Approves quote for presentation to customer.

**Description**: Authorizes quote for customer presentation including final pricing approval, terms validation, and competitive positioning confirmation. May include special pricing or terms requiring higher approval.

**Parameters**:
- `quote_id`: Quote to approve
- `approved_by`: User providing approval
- `approval_level`: Authority level exercised
- `approval_notes`: Comments or conditions
- `pricing_approvals`: Specific pricing approvals granted
- `competitive_info`: Competitive landscape considerations

**Business Rules**:
- Pricing approvals must match authority levels
- Special terms require appropriate authorization
- Competitive pricing requires market analysis
- Quote expiration management

---

#### ConvertQuoteToOrder Command
**Purpose**: Converts accepted quote to active sales order.

**Description**: Transforms accepted quote into sales order including quote validation, price lock confirmation, and order initialization. Handles partial quote conversion and multiple order scenarios.

**Parameters**:
- `quote_id`: Quote being converted
- `selected_line_items`: Items to convert (nil means all)
- `order_split_criteria`: How to split into multiple orders if needed
- `requested_delivery_date`: Customer delivery requirements
- `po_number`: Customer purchase order number
- `special_instructions`: Customer special instructions

**Business Rules**:
- Quote must be approved and within validity period
- Customer acceptance confirmation required
- Price lock validation if prices changed
- Credit check may be required for conversion

---

#### ExpireQuote Command
**Purpose**: Expires quote after validity period or customer decision.

**Description**: Handles quote expiration including automatic expiry based on validity period or manual expiry based on customer decision. Triggers follow-up activities and sales opportunity tracking.

**Parameters**:
- `quote_id`: Quote to expire
- `expiry_reason`: Reason for expiration (time, customer decision, etc.)
- `expiry_type`: Automatic or manual expiry
- `follow_up_required`: Whether follow-up activities needed
- `competitive_loss`: Information if lost to competitor

**Business Rules**:
- Cannot expire quotes already converted to orders
- Follow-up activities based on expiry reason
- Competitive loss tracking for analysis
- Sales opportunity closure procedures

---

### Quote Events

#### QuoteCreated Event
**Purpose**: Records creation of new sales quote.

**Description**: Emitted when quote is successfully created with pricing and terms. Triggers approval workflow and competitive analysis activities.

**Data**:
- `quote_id`: Created quote identifier
- `customer_id`: Customer receiving quote
- `quote_number`: System-assigned quote number
- `total_amount`: Quote total value
- `margin_percentage`: Gross margin on quote
- `validity_period`: Quote expiration date
- `created_by`: User creating quote

**Downstream Effects**:
- Triggers quote approval workflow if required
- Updates sales pipeline projections
- Initiates competitive analysis
- Creates quote tracking and follow-up

---

#### QuoteApproved Event
**Purpose**: Records quote approval and authorization for presentation.

**Description**: Emitted when quote receives all required approvals and is authorized for customer presentation. Enables quote delivery and customer engagement activities.

**Data**:
- `quote_id`: Approved quote
- `approval_timestamp`: When approval completed
- `approved_by`: Final approver
- `approval_level`: Authority level used
- `approval_conditions`: Any special conditions
- `valid_until`: Quote expiration date

**Downstream Effects**:
- Authorizes quote presentation to customer
- Triggers customer engagement activities
- Updates sales pipeline status
- Enables quote tracking and follow-up

---

#### QuoteConvertedToOrder Event
**Purpose**: Records successful conversion of quote to sales order.

**Description**: Emitted when quote is accepted by customer and converted to active sales order. Contains conversion details and triggers order fulfillment workflow.

**Data**:
- `quote_id`: Original quote
- `order_id`: Generated order identifier
- `converted_items`: Items included in conversion
- `conversion_timestamp`: When conversion occurred
- `order_total`: Final order amount
- `payment_terms`: Confirmed payment terms

**Downstream Effects**:
- Initiates order fulfillment workflow
- Updates sales conversion metrics
- Triggers customer order confirmation
- Updates sales pipeline performance

---

## Inventory and Allocation Commands and Events

### Inventory Management

#### AllocateInventory Command
**Purpose**: Allocates inventory to sales order for fulfillment.

**Description**: Reserves inventory for order fulfillment including multi-warehouse allocation, substitute item handling, and backorder creation. Optimizes allocation across available inventory.

**Parameters**:
- `order_id`: Order requiring allocation
- `allocation_strategy`: Approach for allocation (FIFO, optimize shipping, etc.)
- `warehouse_preferences`: Preferred fulfillment locations
- `substitution_allowed`: Whether substitute items acceptable
- `partial_allocation_ok`: Whether partial allocation acceptable

**Business Rules**:
- Available-to-Promise (ATP) calculation validation
- Allocation priority based on customer classification
- Substitute item approval requirements
- Partial allocation customer approval if required

---

#### ReleaseInventoryAllocation Command
**Purpose**: Releases previously allocated inventory back to available stock.

**Description**: Returns allocated inventory to available status including allocation cleanup, availability recalculation, and reallocation optimization for other orders.

**Parameters**:
- `order_id`: Order releasing allocation
- `allocation_id`: Specific allocation to release
- `release_reason`: Reason for release (cancellation, modification, etc.)
- `reallocation_eligible`: Whether inventory can be reallocated immediately

**Business Rules**:
- Cannot release inventory already picked or shipped
- Allocation release authority validation
- Automatic reallocation to waiting orders if configured
- Inventory availability recalculation

---

#### ProcessBackorder Command
**Purpose**: Processes backordered items when inventory becomes available.

**Description**: Handles backorder fulfillment when inventory is received or becomes available including customer notification, allocation processing, and shipment scheduling.

**Parameters**:
- `backorder_id`: Backorder to process
- `available_inventory`: Inventory now available
- `allocation_priority`: Priority for allocation among backorders
- `customer_notification`: Customer communication preferences
- `expedite_shipping`: Whether to expedite for backorder

**Business Rules**:
- Backorder priority based on order date and customer classification
- Customer notification requirements for backorder fulfillment
- Expedited shipping authorization and cost implications
- Partial backorder fulfillment handling

---

### Inventory Events

#### InventoryAllocated Event
**Purpose**: Records successful inventory allocation to order.

**Description**: Emitted when inventory is successfully allocated to sales order. Contains allocation details and triggers fulfillment planning activities.

**Data**:
- `order_id`: Order receiving allocation
- `allocations`: Detailed allocation by item and warehouse
- `warehouse_id`: Primary fulfillment warehouse
- `allocation_timestamp`: When allocation occurred
- `reservation_expiry`: When allocation expires if not used
- `substitute_items`: Any substitute items included

**Downstream Effects**:
- Enables order fulfillment processing
- Updates inventory availability calculations
- Triggers pick list generation when appropriate
- Updates order fulfillment projections

---

#### BackorderCreated Event
**Purpose**: Records creation of backorder for unavailable items.

**Description**: Emitted when items cannot be allocated due to inventory constraints. Creates backorder tracking and triggers customer notification and procurement activities.

**Data**:
- `order_id`: Original order
- `backorder_id`: Backorder identifier
- `backordered_items`: Items and quantities backordered
- `expected_availability`: When inventory expected
- `customer_notified`: Customer notification status
- `procurement_triggered`: Whether procurement was triggered

**Downstream Effects**:
- Creates backorder tracking and monitoring
- Triggers customer communication
- Updates inventory planning and procurement
- Establishes delivery expectation management

---

## Blanket Order Commands and Events

### Blanket Order Management

#### CreateBlanketOrder Command
**Purpose**: Creates master blanket order agreement with customer.

**Description**: Establishes blanket order agreement including quantity commitments, pricing terms, delivery schedules, and release procedures. Provides framework for multiple order releases.

**Parameters**:
- `blanket_order_id`: Unique blanket order identifier
- `customer_id`: Customer with blanket agreement
- `total_quantity_commitment`: Total quantity commitment
- `validity_period`: Agreement validity timeframe
- `pricing_terms`: Locked pricing agreements
- `delivery_schedule`: Planned delivery schedule
- `minimum_release_quantity`: Minimum release amount
- `maximum_release_quantity`: Maximum release amount

**Business Rules**:
- Customer must meet blanket order qualification criteria
- Quantity commitments must be reasonable and achievable
- Pricing lock period must align with validity period
- Release parameters must be operationally feasible

---

#### ReleaseBlanketOrder Command
**Purpose**: Releases specific quantity from blanket order as sales order.

**Description**: Converts portion of blanket order to active sales order including quantity validation, delivery scheduling, and pricing application. Maintains blanket order consumption tracking.

**Parameters**:
- `blanket_order_id`: Source blanket order
- `release_quantity`: Quantity to release
- `requested_delivery_date`: Delivery requirement for release
- `shipping_instructions`: Specific shipping requirements
- `po_number`: Customer purchase order number for release
- `release_type`: Manual, automatic, or scheduled release

**Business Rules**:
- Release quantity within remaining blanket commitment
- Delivery date within blanket order validity period
- Pricing from blanket agreement honored
- Release authorization based on amount

---

#### ExpireBlanketOrder Command
**Purpose**: Expires blanket order at end of validity period.

**Description**: Handles blanket order expiration including commitment fulfillment analysis, unused commitment processing, and agreement closure activities.

**Parameters**:
- `blanket_order_id`: Blanket order to expire
- `expiry_date`: Effective expiration date
- `commitment_fulfillment`: Percentage of commitment fulfilled
- `unused_commitment`: Remaining unfulfilled commitment
- `renewal_opportunity`: Potential for renewal

**Business Rules**:
- Cannot expire with pending releases
- Commitment fulfillment analysis required
- Customer notification for unused commitment
- Renewal opportunity evaluation

---

### Blanket Order Events

#### BlanketOrderCreated Event
**Purpose**: Records creation of new blanket order agreement.

**Description**: Emitted when blanket order agreement is established with customer. Contains agreement terms and triggers ongoing monitoring and management activities.

**Data**:
- `blanket_order_id`: Created agreement identifier
- `customer_id`: Customer with agreement
- `total_commitment`: Total quantity/value commitment
- `validity_period`: Agreement timeframe
- `pricing_agreement`: Locked pricing terms
- `minimum_commitment_percentage`: Minimum fulfillment required

**Downstream Effects**:
- Enables order release processing
- Establishes commitment tracking and monitoring
- Updates customer relationship projections
- Creates agreement audit trail

---

#### BlanketOrderReleased Event
**Purpose**: Records release of quantity from blanket order.

**Description**: Emitted when portion of blanket order is converted to active sales order. Tracks consumption against total commitment and triggers order processing.

**Data**:
- `blanket_order_id`: Source agreement
- `release_id`: Release transaction identifier
- `released_quantity`: Quantity converted to order
- `remaining_quantity`: Remaining blanket commitment
- `generated_order_id`: Created sales order
- `release_date`: When release occurred

**Downstream Effects**:
- Creates active sales order for fulfillment
- Updates blanket order consumption tracking
- Triggers order processing workflow
- Updates commitment fulfillment projections

---

## Recurring Order Commands and Events

### Recurring Order Processing

#### CreateRecurringOrder Command
**Purpose**: Creates recurring order template for automatic order generation.

**Description**: Establishes recurring order template including schedule definition, product specifications, pricing agreements, and automatic generation configuration.

**Parameters**:
- `recurring_order_id`: Unique recurring order identifier
- `customer_id`: Customer for recurring orders
- `template_id`: Product and pricing template
- `schedule_type`: Recurrence pattern (daily, weekly, monthly, custom)
- `schedule_config`: Specific schedule configuration
- `start_date`: When recurring orders begin
- `end_date`: When recurring orders end (if applicable)
- `auto_approval`: Whether to auto-approve generated orders

**Business Rules**:
- Customer must be qualified for recurring orders
- Schedule must be reasonable and achievable
- Pricing terms appropriate for recurring relationship
- Auto-approval limits and authorization

---

#### GenerateRecurringOrder Command
**Purpose**: Generates individual order from recurring template.

**Description**: Creates actual sales order from recurring template including schedule validation, pricing application, inventory checking, and automatic processing configuration.

**Parameters**:
- `recurring_order_id`: Source recurring order template
- `generation_date`: Date for order generation
- `quantity_adjustments`: Any quantity modifications from template
- `pricing_adjustments`: Any pricing changes from template
- `delivery_requirements`: Specific delivery requirements

**Business Rules**:
- Generation must align with configured schedule
- Quantity and pricing adjustments require authorization
- Inventory availability for generated order
- Customer notification requirements

---

#### ModifyRecurringSchedule Command
**Purpose**: Modifies recurring order schedule and parameters.

**Description**: Updates recurring order schedule including frequency changes, quantity adjustments, and delivery modifications. Handles impact on future scheduled orders.

**Parameters**:
- `recurring_order_id`: Recurring order to modify
- `new_schedule`: Updated schedule configuration
- `effective_date`: When changes become effective
- `modify_future_orders_only`: Whether to affect pending orders
- `reason`: Justification for schedule change

**Business Rules**:
- Schedule changes require customer agreement
- Cannot modify past or processing orders
- Pricing impact analysis for schedule changes
- Customer notification for significant changes

---

#### SuspendRecurringOrder Command
**Purpose**: Suspends recurring order processing temporarily or permanently.

**Description**: Stops automatic recurring order generation including suspension period definition, pending order handling, and resumption criteria establishment.

**Parameters**:
- `recurring_order_id`: Recurring order to suspend
- `suspension_reason`: Reason for suspension
- `suspension_start_date`: When suspension begins
- `suspension_end_date`: When suspension ends (if temporary)
- `handle_pending_orders`: How to handle orders already generated

**Business Rules**:
- Suspension authorization based on customer relationship
- Pending order handling requires customer input
- Temporary suspensions must have end dates
- Customer notification requirements

---

### Recurring Order Events

#### RecurringOrderCreated Event
**Purpose**: Records creation of recurring order template.

**Description**: Emitted when recurring order template is established with customer. Contains template configuration and triggers ongoing monitoring and generation activities.

**Data**:
- `recurring_order_id`: Created template identifier
- `customer_id`: Customer with recurring agreement
- `template_id`: Product template used
- `schedule`: Configured recurrence schedule
- `start_date`: When generation begins
- `end_date`: When generation ends (if applicable)
- `auto_renewal_enabled`: Whether agreement auto-renews

**Downstream Effects**:
- Enables automatic order generation
- Establishes schedule monitoring and execution
- Updates customer relationship tracking
- Creates recurring order audit trail

---

#### RecurringOrderGenerated Event
**Purpose**: Records automatic generation of order from template.

**Description**: Emitted when individual order is automatically generated from recurring template. Contains generated order details and schedule progression information.

**Data**:
- `recurring_order_id`: Source template
- `generated_order_id`: Created order identifier
- `generation_date`: When order was generated
- `order_items`: Items included in generated order
- `order_total`: Total value of generated order
- `next_scheduled_date`: Next generation date

**Downstream Effects**:
- Creates active sales order for processing
- Updates recurring order tracking and metrics
- Triggers order processing workflow
- Updates schedule for next generation

---

## Advanced Billing Commands and Events

### Advanced Billing Processing

#### CreateAdvancedBilling Command
**Purpose**: Creates advanced billing arrangement for complex orders.

**Description**: Establishes advanced billing including milestone billing, progress billing, or contract-based billing arrangements. Handles complex billing scenarios beyond standard shipment billing.

**Parameters**:
- `order_id`: Order requiring advanced billing
- `billing_type`: Type of advanced billing (milestone, progress, contract)
- `billing_schedule`: Schedule for billing events
- `milestone_definitions`: Milestone criteria if applicable
- `progress_measurement`: Progress measurement method
- `payment_terms`: Payment terms for each billing event

**Business Rules**:
- Advanced billing authorization required
- Billing schedule must align with delivery schedule
- Milestone definitions must be measurable
- Progress measurement must be objective

---

#### ProcessMilestoneBilling Command
**Purpose**: Processes billing for completed milestone.

**Description**: Creates billing for completed milestone including milestone validation, amount calculation, and invoice generation. Handles milestone-based revenue recognition.

**Parameters**:
- `milestone_id`: Completed milestone
- `completion_evidence`: Evidence of milestone completion
- `billing_amount`: Amount to bill for milestone
- `completion_date`: When milestone was completed
- `invoice_timing`: When to generate invoice

**Business Rules**:
- Milestone completion must be verified
- Billing amount must match milestone agreement
- Completion evidence required for billing
- Revenue recognition timing compliance

---

### Advanced Billing Events

#### AdvancedBillingCreated Event
**Purpose**: Records creation of advanced billing arrangement.

**Description**: Emitted when advanced billing arrangement is established for order. Contains billing configuration and triggers monitoring and execution activities.

**Data**:
- `advance_bill_id`: Billing arrangement identifier
- `order_id`: Associated order
- `customer_id`: Customer with billing arrangement
- `billing_type`: Type of advanced billing
- `total_amount`: Total amount to be billed
- `billing_schedule`: Schedule for billing events

**Downstream Effects**:
- Enables milestone or progress billing
- Establishes billing monitoring and tracking
- Updates revenue recognition projections
- Creates billing audit trail

---

#### MilestoneBillingProcessed Event
**Purpose**: Records processing of milestone billing event.

**Description**: Emitted when milestone billing is processed including invoice generation and revenue recognition. Tracks milestone completion and billing progress.

**Data**:
- `milestone_id`: Processed milestone
- `invoice_id`: Generated invoice
- `billing_amount`: Amount billed
- `completion_date`: Milestone completion date
- `revenue_recognized`: Revenue recognition amount
- `remaining_milestones`: Outstanding milestone count

**Downstream Effects**:
- Generates customer invoice
- Triggers revenue recognition posting
- Updates milestone completion tracking
- Advances billing schedule progression

---

## Kit and Assembly Commands and Events

### Kit Management

#### ConfigureKitComponents Command
**Purpose**: Configures components for kit items including substitution rules.

**Description**: Sets up kit component relationships including quantity requirements, substitution options, and assembly instructions. Handles complex kit configurations with optional components.

**Parameters**:
- `kit_item_id`: Kit item being configured
- `components`: List of component items and quantities
- `assembly_instructions`: How kit should be assembled
- `substitution_rules`: Acceptable substitute components
- `optional_components`: Components that are optional

**Business Rules**:
- All components must be valid inventory items
- Component quantities must be positive
- Substitution rules must maintain functionality
- Optional components must be clearly marked

---

#### ExplodeKitComponents Command
**Purpose**: Explodes kit into component requirements for order processing.

**Description**: Breaks down kit items into individual component requirements including quantity calculations, availability checking, and component allocation for order fulfillment.

**Parameters**:
- `order_id`: Order containing kit items
- `kit_line_items`: Specific kit line items to explode
- `explosion_date`: Date for explosion calculation
- `warehouse_context`: Warehouse for component availability
- `substitution_preferences`: Component substitution preferences

**Business Rules**:
- Kit explosion must account for all components
- Component availability validation required
- Substitution authorization for out-of-stock components
- Component allocation follows standard allocation rules

---

#### AssembleKit Command
**Purpose**: Processes kit assembly including component consumption.

**Description**: Coordinates kit assembly process including component consumption, assembly processing, and finished kit receipt. Handles assembly validation and quality control.

**Parameters**:
- `assembly_order_id`: Assembly order identifier
- `kit_item_id`: Kit being assembled
- `assembly_quantity`: Number of kits to assemble
- `component_allocations`: Specific component allocations
- `quality_requirements`: Quality control requirements

**Business Rules**:
- All components must be allocated and available
- Assembly quantity must be achievable with available components
- Quality requirements must be met
- Assembly processing authorization required

---

### Kit Events

#### KitComponentsConfigured Event
**Purpose**: Records configuration of kit component relationships.

**Description**: Emitted when kit component configuration is established or updated. Contains component definitions and triggers assembly capability validation.

**Data**:
- `kit_item_id`: Configured kit item
- `components`: List of components and quantities
- `assembly_method`: How kit should be assembled
- `substitution_rules`: Acceptable substitutions
- `cost_calculation`: How kit cost is calculated

**Downstream Effects**:
- Enables kit ordering and quoting
- Updates kit availability calculations
- Triggers component availability monitoring
- Updates kit costing calculations

---

#### KitExploded Event
**Purpose**: Records explosion of kit into component requirements.

**Description**: Emitted when kit is exploded into component requirements for order processing. Contains detailed component requirements and availability status.

**Data**:
- `order_id`: Order with exploded kit
- `kit_item_id`: Kit that was exploded
- `component_requirements`: Required components and quantities
- `availability_status`: Component availability results
- `substitutions_required`: Components requiring substitution

**Downstream Effects**:
- Triggers component allocation workflow
- Updates component demand projections
- Initiates substitution approval if needed
- Updates kit fulfillment tracking

---

## Customer Integration Commands and Events

### Customer Management

#### ValidateCustomerCredit Command
**Purpose**: Validates customer credit for order processing.

**Description**: Performs customer credit validation including credit limit checking, payment history analysis, and credit risk assessment. Determines appropriate credit terms and authorization levels.

**Parameters**:
- `customer_id`: Customer to validate
- `order_amount`: Amount requiring credit approval
- `credit_check_type`: Type of credit check (soft, hard, enhanced)
- `existing_exposure`: Current customer exposure
- `payment_terms_requested`: Requested payment terms

**Business Rules**:
- Credit check type appropriate for order value
- Existing exposure included in limit calculation
- Payment terms must align with credit assessment
- Enhanced checks for new or high-risk customers

---

#### ProcessCustomerCommunication Command
**Purpose**: Manages customer communication for order-related activities.

**Description**: Coordinates customer communication including order confirmations, shipping notifications, delivery confirmations, and exception notifications. Handles multi-channel communication preferences.

**Parameters**:
- `communication_id`: Communication request identifier
- `customer_id`: Customer to communicate with
- `communication_type`: Type of communication (confirmation, notification, etc.)
- `order_context`: Order-related context for communication
- `delivery_preferences`: Customer communication preferences
- `urgency_level`: Priority level for communication

**Business Rules**:
- Communication preferences must be respected
- Urgent communications may override preferences
- Order context must be accurate and complete
- Privacy and compliance requirements

---

### Customer Events

#### CustomerCreditValidated Event
**Purpose**: Records completion of customer credit validation.

**Description**: Emitted when customer credit check completes with approval status and terms. Enables or restricts order processing based on credit results.

**Data**:
- `customer_id`: Validated customer
- `credit_approved`: Whether credit was approved
- `approved_amount`: Amount approved for credit
- `credit_terms`: Approved payment terms
- `credit_limit`: Customer credit limit
- `validation_timestamp`: When validation completed

**Downstream Effects**:
- Authorizes or restricts order processing
- Updates customer credit projections
- Triggers credit monitoring if needed
- Enables order approval workflow continuation

---

#### CustomerCommunicationSent Event
**Purpose**: Records customer communication delivery.

**Description**: Emitted when communication is successfully sent to customer. Tracks communication history and ensures customer is informed of order status.

**Data**:
- `communication_id`: Communication identifier
- `customer_id`: Customer receiving communication
- `communication_type`: Type of communication sent
- `delivery_method`: How communication was delivered
- `delivery_confirmation`: Delivery confirmation if available
- `sent_at`: When communication was sent

**Downstream Effects**:
- Updates customer communication history
- Triggers delivery tracking if applicable
- Updates customer engagement metrics
- Completes communication workflow

---

## Import and Data Management Commands and Events

### Data Import Processing

#### InitiateImport Command
**Purpose**: Starts bulk import of sales order data.

**Description**: Begins import process including file validation, data transformation, business rule validation, and batch processing setup. Handles various import sources and formats.

**Parameters**:
- `batch_id`: Import batch identifier
- `source_file`: Source file or data stream
- `import_template_id`: Template for data mapping
- `validation_rules`: Business rules to apply
- `processing_options`: How to handle errors and exceptions

**Business Rules**:
- Source file format validation
- Import template compatibility
- Data volume within processing limits
- Authorization for bulk import operations

---

#### ValidateImportData Command
**Purpose**: Validates imported data against business rules.

**Description**: Executes comprehensive validation of imported data including customer validation, product validation, pricing validation, and business rule compliance.

**Parameters**:
- `batch_id`: Import batch to validate
- `validation_scope`: Scope of validation (full, incremental, spot-check)
- `error_tolerance`: Acceptable error rate for processing
- `auto_correction`: Whether to auto-correct certain errors

**Business Rules**:
- All referenced customers and products must exist
- Pricing must be within acceptable ranges
- Business rules must pass for all records
- Error tolerance within acceptable limits

---

#### ProcessImportBatch Command
**Purpose**: Processes validated import data into active orders.

**Description**: Converts validated import data into active sales orders including order creation, workflow initiation, and error handling for failed conversions.

**Parameters**:
- `batch_id`: Import batch to process
- `processing_strategy`: How to process (sequential, parallel, prioritized)
- `error_handling`: How to handle processing errors
- `notification_settings`: Progress notification configuration

**Business Rules**:
- All data must be validated before processing
- Processing strategy appropriate for data volume
- Error handling must preserve data integrity
- Progress tracking and notification requirements

---

### Import Events

#### ImportBatchValidated Event
**Purpose**: Records completion of import data validation.

**Description**: Emitted when import batch validation completes with results. Contains validation summary and enables processing decision making.

**Data**:
- `batch_id`: Validated import batch
- `total_records`: Total records in batch
- `valid_records`: Records passing validation
- `invalid_records`: Records failing validation
- `validation_summary`: Summary of validation results
- `processing_recommended`: Whether processing should continue

**Downstream Effects**:
- Enables import processing decision
- Updates import progress tracking
- Triggers error resolution workflow if needed
- Updates import performance metrics

---

#### ImportProcessingCompleted Event
**Purpose**: Records completion of import batch processing.

**Description**: Emitted when import processing completes with summary of results. Contains processing statistics and triggers cleanup and notification activities.

**Data**:
- `batch_id`: Processed import batch
- `successful_orders`: Orders successfully created
- `failed_records`: Records that failed processing
- `processing_duration`: Time taken for processing
- `error_summary`: Summary of processing errors
- `completion_timestamp`: Processing completion time

**Downstream Effects**:
- Completes import audit trail
- Triggers user notification of results
- Updates import performance metrics
- Initiates cleanup activities

---

## Summary

The Sales Orders domain contains **35 primary command types** and **30 primary event types** organized into:

**Order Management**: Order creation, approval, cancellation, and hold management commands with corresponding lifecycle events
**Shipment Processing**: Shipment creation, partial shipment, over-shipment, and delivery commands with fulfillment status events  
**Quote Management**: Quote creation, approval, conversion, and expiration commands with quote lifecycle events
**Inventory Operations**: Inventory allocation, release, and backorder commands with availability and allocation events
**Blanket Orders**: Blanket order creation, release, and expiration commands with agreement lifecycle events
**Recurring Orders**: Recurring order template creation, generation, and schedule management commands with automation events
**Advanced Billing**: Complex billing arrangement and milestone processing commands with billing lifecycle events
**Kit Management**: Kit configuration, explosion, and assembly commands with kit processing events
**Customer Integration**: Credit validation and communication commands with customer interaction events
**Import Operations**: Bulk import initiation, validation, and processing commands with import lifecycle events

Each command includes detailed parameters, business rules, and validation requirements, while events provide comprehensive data about system state changes and trigger appropriate downstream processing. The design supports complex sales order business processes including multi-warehouse fulfillment, sophisticated pricing, kit management, blanket agreements, recurring orders, and advanced billing scenarios while maintaining data integrity, audit compliance, and system reliability.