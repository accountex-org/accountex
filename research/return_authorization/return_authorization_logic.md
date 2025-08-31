# Return Merchandise Authorization Logic

## Overview

The Return Merchandise Authorization (RMA) application manages the complete lifecycle of customer returns, from authorization through receipt, replacement/repair, and final disposition. The system handles warranty validation, inventory adjustments, credit issuance, and replacement shipments while maintaining full audit trails through event sourcing.

## Core Business Concepts

### Return Authorization

A formal agreement to accept returned merchandise from a customer, defining the terms, conditions, and actions to be taken with the returned items.

### Return Actions

The disposition strategy for returned items:

- **Credit**: Issue credit note without requiring physical return
- **Restock**: Return items to available inventory
- **Repair**: Fix items and return to customer
- **Replace**: Send identical replacement items
- **Substitute**: Send alternative items as replacement
- **Discard**: Dispose of returned items

### Warranty Management

Time-based authorization for returns, including manufacturer warranties and internal return policies.

### Defective Inventory

Segregated inventory pool for items awaiting repair, disposal, or vendor return.

## Core Aggregates

### RMAOrder

The primary aggregate managing the return authorization lifecycle.

**Commands:**

- `CreateRMAOrder`
- `AmendRMAOrder`
- `CancelRMAOrder`
- `PlaceRMAOnHold`
- `ReleaseRMAFromHold`

**Events:**

- `RMAOrderCreated`
- `RMAOrderAmended`
- `RMAOrderCancelled`
- `RMAOrderPlacedOnHold`
- `RMAOrderReleasedFromHold`

### RMAReceipt

Manages the physical receipt of returned items.

**Commands:**

- `ReceiveRMAItems`
- `AdjustReceivedQuantity`
- `GenerateCreditInvoice`
- `CancelRMAReceipt`

**Events:**

- `RMAItemsReceived`
- `ReceivedQuantityAdjusted`
- `CreditInvoiceGenerated`
- `RMAReceiptCancelled`

### RMAShipment

Handles shipping of replacement or repaired items.

**Commands:**

- `ShipReplacementItems`
- `ShipRepairedItems`
- `ShipSubstituteItems`
- `CancelRMAShipment`

**Events:**

- `ReplacementItemsShipped`
- `RepairedItemsShipped`
- `SubstituteItemsShipped`
- `RMAShipmentCancelled`

### RMACompletion

Manages the finalization of RMA transactions.

**Commands:**

- `CompleteRMAOrder`
- `PartiallyCompleteRMAOrder`
- `ReverseRMACompletion`

**Events:**

- `RMAOrderCompleted`
- `RMAOrderPartiallyCompleted`
- `RMACompletionReversed`

## Supporting Resources

### ReturnCode

Defines return handling rules and actions.

**Attributes:**

- `code`: String
- `description`: String
- `return_action`: Enum[:credit, :restock, :repair, :replace, :substitute, :discard]
- `requires_receipt`: Boolean
- `allows_partial_return`: Boolean
- `restocking_fee_percentage`: Decimal
- `warranty_required`: Boolean
- `max_return_days`: Integer
- `auto_generate_credit`: Boolean
- `gl_accounts`: Map

### InventoryWarranty

Tracks warranty periods for inventory items.

**Attributes:**

- `item_id`: UUID
- `warranty_days`: Integer
- `warranty_type`: Enum[:manufacturer, :extended, :internal]
- `coverage_type`: Enum[:full, :limited, :parts_only]
- `vendor_warranty_days`: Integer

### Claimperson

Personnel authorized to handle RMA transactions.

**Attributes:**

- `employee_id`: UUID
- `name`: String
- `authorization_level`: Enum[:basic, :supervisor, :manager]
- `max_authorization_amount`: Decimal

### DefectiveInventoryLocation

Segregated storage for defective items.

**Attributes:**

- `warehouse_id`: UUID
- `bin_code`: String
- `quarantine_zone`: Boolean

## Business Processes

### RMA Creation Process

1. **Validate Return Eligibility**
   - Check original invoice exists
   - Validate within return period
   - Verify warranty status if applicable
   - Check return authorization limits

2. **Calculate Charges**
   - Restocking fees based on return code
   - Repair charges if applicable
   - Shipping charges for replacements

3. **Reserve Inventory** (if replacement/substitute)
   - Allocate replacement items
   - Update availability

4. **Generate RMA Number**
   - System-generated or manual entry
   - Unique within fiscal year

### Receipt Process

1. **Validate Receipt**
   - Match against open RMA
   - Verify quantities don't exceed authorized
   - Check item condition codes

2. **Update Inventory**
   - Increase on-hand (if restock action)
   - Increase defective quantity (if repair action)
   - No inventory impact (if discard/credit action)

3. **Process Serial/Lot Numbers**
   - Track returned serial numbers
   - Update lot quantities
   - Maintain traceability

4. **Generate Credit Documents**
   - Create credit invoice if configured
   - Calculate credit amount
   - Apply taxes and adjustments

### Shipment Process

1. **Validate Shipment Eligibility**
   - Verify receipt completed (if required)
   - Check replacement inventory availability
   - Validate repair completion

2. **Allocate Inventory**
   - Reserve replacement/substitute items
   - Update committed quantities

3. **Calculate Costs**
   - Determine replacement cost
   - Calculate gain/loss on substitution
   - Apply shipping charges

4. **Generate Shipping Documents**
   - Create AR invoice
   - Generate packing slip
   - Update shipment tracking

### Completion Process

1. **Validate Completion**
   - All items received or waived
   - All replacements shipped or cancelled
   - Credits applied or pending

2. **Calculate Final Adjustments**
   - Net gain/loss on transaction
   - Final charge reconciliation
   - Commission adjustments

3. **Update Status**
   - Mark RMA as complete
   - Release any holds
   - Archive transaction

## Integration Points

### With Inventory Application

- Query item availability
- Update on-hand quantities
- Manage defective inventory
- Track serial/lot numbers

### With Sales Order Application

- Reference original invoices
- Create replacement orders
- Generate credit invoices

### With Accounts Receivable

- Apply credit memos
- Process refunds
- Update customer balances

### With General Ledger

- Post inventory adjustments
- Record gains/losses
- Update COGS accounts

## Business Rules

### Return Authorization

- Returns must reference valid original transaction
- Returns within warranty period bypass time restrictions
- Partial returns allowed based on return code configuration
- Serialized items require exact serial number match

### Inventory Management

- Restock action increases available inventory
- Repair action increases defective inventory
- Discard action removes from all inventory
- Substitute items must be explicitly mapped

### Credit Processing

- Credits generated at receipt or completion
- Restocking fees reduce credit amount
- Repair charges posted separately
- Tax credits calculated based on original invoice

### Replacement Shipping

- Can ship before receipt if configured
- Substitutes require customer approval flag
- Gain/loss calculated on cost differential
- Original pricing honored for replacements

## Workflow States

### RMA Order States

- `draft`: Initial creation
- `authorized`: Approved for return
- `on_hold`: Temporarily suspended
- `receiving`: Actively receiving items
- `received`: All items received
- `shipping`: Sending replacements
- `completed`: Fully processed
- `cancelled`: Voided

### Line Item States

- `pending`: Awaiting action
- `partially_received`: Some quantity received
- `received`: Fully received
- `partially_shipped`: Some replacements sent
- `shipped`: All replacements sent
- `completed`: Fully processed
- `cancelled`: Line cancelled

## Calculations

### Restocking Fee

```
restocking_fee = (item_extended_price * restocking_percentage) 
                 OR minimum_restocking_amount (whichever is greater)
```

### Credit Amount

```
credit_amount = (return_quantity * unit_price) 
                - restocking_fee 
                - repair_charges 
                + tax_credit
```

### Replacement Gain/Loss

```
gain_loss = (original_item_cost * return_quantity) 
            - (replacement_item_cost * ship_quantity)
```

## Validation Rules

### Create RMA

- Customer must be active
- Referenced invoice must exist
- Return period must not be exceeded (unless under warranty)
- Claimperson must be authorized
- Return code must be valid

### Receive Items

- RMA must be authorized and not on hold
- Received quantity cannot exceed authorized
- Serial numbers must match shipped items
- Lot numbers must be valid
- Warehouse must accept returns

### Ship Replacements

- Original items must be received (if required)
- Replacement items must be available
- Shipping address must be valid
- Payment terms must be current

### Complete RMA

- All authorized items accounted for
- All credits properly applied
- All replacements shipped or cancelled
- No pending adjustments

## Event Handlers

### On Original Invoice Created

- Enable RMA creation for invoice items
- Start return period timer
- Track warranty start dates

### On RMA Items Received

- Update inventory quantities
- Generate credit invoice if configured
- Trigger quality inspection workflow
- Notify warehouse of defective items

### On Replacement Items Shipped

- Create AR invoice
- Update customer balance
- Calculate commission adjustments
- Track shipment for completion

### On RMA Completed

- Archive transaction
- Update customer return history
- Calculate period-end adjustments
- Release any reserved resources

## Configuration Options

### Module Level

- `allow_shipment_before_receipt`: Boolean
- `auto_generate_rma_number`: Boolean
- `auto_generate_credit_on_receipt`: Boolean
- `default_return_code`: String
- `default_warranty_days`: Integer
- `require_original_invoice`: Boolean
- `allow_negative_inventory`: Boolean

### Return Code Level

- `return_action`: Action type
- `auto_credit`: Boolean
- `restocking_fee`: Percentage
- `allow_partial`: Boolean
- `max_return_days`: Integer
- `warranty_override`: Boolean

### Customer Level

- `return_authorization_required`: Boolean
- `max_return_percentage`: Decimal
- `preferred_return_method`: Enum
- `waive_restocking_fee`: Boolean

# Return Merchandise Authorization Business Logic

## Overview

The Return Merchandise Authorization (RMA) module manages the complete lifecycle of product returns, from initial authorization through receipt, repair/replacement, and final credit application. This document outlines the business logic required to implement a comprehensive RMA system within the Accountex modular architecture.

## Core Domain Concepts

### Primary Entities

#### Return Authorization

- Unique RMA number (system-generated or manual)
- Customer reference
- Authorization date and expiration
- Return reason codes
- Status tracking (Open, Partially Received, Received, Shipped, Completed, Cancelled, Voided)
- Claimperson assignment
- Associated documents (original invoice, sales order)

#### RMA Line Item

- Item identification (inventory item or customer item number)
- Quantity authorized/received/shipped/completed
- Return code and action
- Unit price and extended amounts
- Defect status and repair requirements
- Serial/lot number tracking
- Warranty status

#### Return Code

- Code identifier
- Return actions (Credit, Replace, Repair, Restock)
- GL account mappings
- Charge definitions (restocking fee, repair charge)
- Reason categorization

#### Defective Inventory

- Warehouse location
- Defective quantity tracking
- Repair status
- Transfer history
- Cost tracking

## Business Rules and Validations

### RMA Creation Rules

1. **Authorization Requirements**
   - Must reference valid customer
   - Optional reference to original invoice/sales order
   - Must specify return reason code
   - Must define authorization expiration date
   - Claimperson assignment required if configured

2. **Line Item Validations**
   - Quantity must be positive
   - Return code must be active
   - Serial/lot numbers must match original sale (if tracked)
   - Warranty validation against warranty period
   - Price validation against original sale price

3. **Credit Limit Checks**
   - Total credit amount validation
   - Customer credit balance impact
   - Authorization approval requirements based on amount

### Receiving Rules

1. **Receipt Validation**
   - Cannot exceed authorized quantity
   - Must match specified items
   - Serial/lot number verification
   - Quality inspection requirements
   - Defective status determination

2. **Inventory Impact**
   - Update on-hand quantities based on return code
   - Segregate defective inventory
   - Update available quantities
   - Cost layer management for returned items

3. **Partial Receipt Handling**
   - Allow multiple receipts per RMA
   - Track not-yet-received quantities
   - Status progression logic

### Shipping Rules (Replacement/Repair)

1. **Shipment Authorization**
   - Must have received items (for repair/replace)
   - Inventory availability check
   - Substitute item validation
   - Shipping address verification

2. **Inventory Allocation**
   - Reserve replacement inventory
   - Track repair completion
   - Serial/lot assignment for replacements
   - Cost tracking for shipped items

3. **Document Generation**
   - Packing slip creation
   - Shipping notification
   - Tracking information capture

### Completion Rules

1. **Completion Requirements**
   - All actions must be fulfilled
   - Credit memo generation
   - Invoice creation for charges
   - GL posting validation

2. **Financial Impact**
   - Calculate net credit/charge
   - Apply restocking fees
   - Apply repair charges
   - Tax recalculation

## Core Workflows

### RMA Creation Workflow

```
1. Initialize RMA
   - Generate RMA number
   - Set initial status: Open
   - Capture customer information
   
2. Add Line Items
   - Validate each item
   - Apply return codes
   - Calculate preliminary amounts
   
3. Apply Business Rules
   - Check authorization limits
   - Validate warranty status
   - Apply pricing rules
   
4. Finalize Authorization
   - Set expiration date
   - Assign claimperson
   - Generate RMA document
   - Emit RMACreated event
```

### Receiving Workflow

```
1. Validate Receipt
   - Match against open RMA
   - Verify quantities
   - Check item condition
   
2. Process Inventory
   - Update quantities based on return code
   - Segregate defective items
   - Update cost layers
   
3. Update RMA Status
   - Mark items as received
   - Calculate received totals
   - Update overall status
   - Emit RMAItemsReceived event
```

### Shipping Workflow (Replacement/Repair)

```
1. Validate Shipment
   - Check received status
   - Verify inventory availability
   - Validate shipping address
   
2. Allocate Inventory
   - Reserve replacement items
   - Assign serial/lot numbers
   - Calculate shipping costs
   
3. Generate Shipment
   - Create packing slip
   - Update RMA status
   - Reduce inventory
   - Emit RMAItemsShipped event
```

### Completion Workflow

```
1. Validate Completion
   - Check all items processed
   - Verify all actions completed
   - Calculate final amounts
   
2. Generate Financial Documents
   - Create credit memo
   - Generate charge invoice
   - Calculate net amount
   
3. Update Records
   - Close RMA
   - Post to GL
   - Update customer balance
   - Emit RMACompleted event
```

## Integration Points

### Sales Order Module

- Reference original sales orders
- Validate pricing and terms
- Check warranty periods
- Link to original shipments

### Inventory Control Module

- Update on-hand quantities
- Manage defective inventory
- Track serial/lot numbers
- Handle cost layers
- Process inventory transfers

### Accounts Receivable Module

- Generate credit memos
- Create charge invoices
- Update customer balances
- Apply credits to open invoices

### General Ledger Module

- Post return transactions
- Record inventory adjustments
- Track cost of goods returned
- Record repair expenses

### Warehouse Management

- Receive returned goods
- Manage defective inventory locations
- Process replacement shipments
- Track repair queue

## Event Definitions

### Commands

- CreateRMA
- AddRMALineItem
- ReceiveRMAItems
- ShipReplacementItems
- CompleteRMA
- CancelRMA
- TransferDefectiveInventory
- ApplyRMACredit

### Events

- RMACreated
- RMALineItemAdded
- RMAItemsReceived
- ReplacementItemsShipped
- RMACompleted
- RMACancelled
- DefectiveInventoryTransferred
- RMACreditApplied
- RMAStatusChanged

## Business Process Specifications

### Return Code Processing

1. **Credit Only**
   - Generate credit memo
   - Return items to inventory (if resalable)
   - Update customer balance

2. **Replace**
   - Receive defective item
   - Ship replacement
   - Track exchange costs

3. **Repair**
   - Receive item for repair
   - Track repair status
   - Ship repaired item back
   - Apply repair charges

4. **Restock**
   - Receive returned item
   - Apply restocking fee
   - Return to saleable inventory

### Defective Inventory Management

1. **Segregation**
   - Separate defective from good inventory
   - Track by warehouse/bin
   - Maintain repair queue

2. **Transfer Processing**
   - Move between warehouses
   - Track in-transit items
   - Update location records

3. **Disposition**
   - Repair and return to stock
   - Scrap with proper documentation
   - Return to vendor

### Credit Application

1. **Credit Calculation**
   - Item credit amount
   - Less: restocking fees
   - Less: repair charges
   - Plus: tax adjustments
   - Net credit amount

2. **Application Options**
   - Apply to specific invoices
   - Apply to oldest invoices
   - Hold as open credit
   - Issue refund

## Reporting Requirements

### Operational Reports

- Open RMA listing
- Received but not completed
- Items awaiting shipment
- Defective inventory status
- RMA aging report

### Financial Reports

- Credit memo register
- RMA profitability analysis
- Restocking fee summary
- Repair charge analysis
- GL impact report

### Analysis Reports

- Return reason analysis
- Product return rates
- Customer return patterns
- Warranty claim analysis
- Defect rate by product

## Configuration and Settings

### Module Configuration

- RMA number generation (auto/manual)
- Default expiration days
- Require original invoice reference
- Allow negative inventory for returns
- Default return codes by product category

### Approval Workflows

- Credit limit thresholds
- Automatic approval rules
- Escalation procedures
- Override permissions

### Integration Settings

- GL account mappings
- Inventory update timing
- Credit application rules
- Document generation templates

## Performance Considerations

### Optimization Points

- RMA lookup and search indexing
- Inventory availability caching
- Credit calculation efficiency
- Document generation queuing

### Scalability Factors

- High-volume return processing
- Multiple warehouse coordination
- Concurrent receipt processing
- Real-time inventory updates

## Compliance and Audit

### Audit Trail Requirements

- All status changes logged
- User actions tracked
- Amount adjustments documented
- Override reasons captured

### Compliance Controls

- Return authorization limits
- Segregation of duties
- Credit approval hierarchies
- Inventory adjustment controls

## Exception Handling

### Common Exceptions

- Expired RMA processing
- Over-receipt situations
- Inventory shortage for replacement
- Credit limit exceeded
- Invalid serial/lot numbers

### Resolution Procedures

- Override capabilities
- Escalation workflows
- Exception reporting
- Manual adjustment procedures:

# Return Merchandise Authorization Business Logic

## Overview

The Return Merchandise Authorization (RMA) application manages the complete lifecycle of product returns, both from customers (RMA) and to vendors (RTV). This document outlines the business logic required to implement comprehensive return processing within the Accountex modular application architecture.

## Core Business Entities

### 1. Return Authorization Order

- **RMA Order**: Customer return authorization
- **RTV Order**: Vendor return authorization
- **Return Code**: Defines return actions and policies
- **Reason Code**: Categorizes return reasons
- **Return Line Item**: Individual items within a return order

### 2. Return Actions

#### Customer Return Actions (RMA)

- **Restock and Credit**: Accept return, restock inventory, issue credit
- **Restock and Replace**: Accept return, restock, ship replacement
- **Restock and Substitute**: Accept return, restock, ship substitute item
- **Discard and Credit**: Dispose of return, issue credit
- **Discard and Replace**: Dispose of return, ship replacement
- **Discard and Substitute**: Dispose of return, ship substitute
- **Repair and Return**: Repair item and return to customer

#### Vendor Return Actions (RTV)

- **Return for Replacement**: Return defective item, receive replacement
- **Return for Substitution**: Return item, receive substitute
- **Return for Repair**: Send for repair, receive repaired item
- **Repair and Substitute**: Send for repair, receive substitute
- **Repair and Credit**: Send for repair, receive credit
- **Return for Credit**: Return item for credit only

## Business Processes

### 1. Return Authorization Creation

#### Process Flow

1. **Initiation**
   - Customer/vendor contact initiates return request
   - System validates eligibility based on:
     - Invoice date vs. warranty period
     - Item return eligibility
     - Previous return history

2. **Authorization Generation**
   - Assign unique RMA/RTV number
   - Link to original invoice/purchase order
   - Apply return code with defined actions
   - Calculate applicable charges/credits

3. **Line Item Processing**
   - Validate each item against:
     - Original transaction
     - Warranty status
     - Return eligibility flags
   - Calculate return value based on:
     - Original price
     - Quantity
     - Applicable discounts
     - Restocking fees

#### Business Rules

- Items must exist in original transaction
- Return quantity cannot exceed original quantity minus previously returned
- Warranty validation against item-specific or invoice-date based periods
- Return codes must be active and applicable to item type

### 2. Goods Receipt Processing

#### Process Flow

1. **Receipt Recording**
   - Verify received items against RMA/RTV
   - Record actual received quantities
   - Assess item condition
   - Update return status

2. **Inventory Impact**
   - For restock actions:
     - Increase inventory on-hand quantity
     - Update inventory valuation
   - For discard actions:
     - No inventory impact
     - Record disposal
   - For repair actions:
     - Move to defective inventory
     - Track repair status

3. **Quality Assessment**
   - Determine actual item condition
   - Validate return code appropriateness
   - Adjust processing if needed

#### Business Rules

- Received quantity cannot exceed authorized quantity
- Partial receipts allowed with tracking
- Condition assessment may override return action
- Serial/lot number tracking for applicable items

### 3. Replacement/Substitute Shipment

#### Process Flow

1. **Shipment Authorization**
   - Validate replacement/substitute items availability
   - Create shipment order
   - Link to original RMA/RTV

2. **Inventory Allocation**
   - Reserve replacement/substitute items
   - Update booked quantities
   - Generate pick list

3. **Shipment Execution**
   - Process shipment
   - Update inventory
   - Generate shipping documents
   - Track shipment status

#### Business Rules

- Replacement must be same item as returned
- Substitute must be pre-defined acceptable alternative
- Can ship before receipt if authorized by return code
- Shipping method follows original order or default rules

### 4. Financial Processing

#### Credit/Debit Calculation

1. **Customer Credits (RMA)**
   - Base credit amount = Original price × Return quantity
   - Less: Restocking fees (percentage or minimum)
   - Less: Repair charges (if applicable)
   - Plus: Tax credits (if applicable)

2. **Vendor Debits (RTV)**
   - Debit amount = Purchase price × Return quantity
   - Plus: Return shipping costs (if applicable)
   - Adjust for price variance

#### Accounting Impact

1. **RMA Transactions**
   - Debit: Sales Returns and Allowances
   - Credit: Accounts Receivable
   - Inventory adjustments for restocked items
   - COGS reversal for returned items

2. **RTV Transactions**
   - Debit: Accounts Payable
   - Credit: Purchase Returns
   - Inventory adjustments
   - Cost variance recognition

### 5. Return Completion

#### Process Flow

1. **Validation**
   - Verify all line items processed
   - Confirm receipts recorded
   - Validate shipments completed

2. **Financial Finalization**
   - Generate credit memo/debit memo
   - Apply to customer/vendor account
   - Update aging
   - Post to general ledger

3. **Status Update**
   - Mark return as completed
   - Update related transactions
   - Trigger notifications

#### Business Rules

- Cannot complete with open line items
- Financial documents auto-generate on completion
- Completed returns cannot be modified
- Audit trail maintained for all changes

## Integration Points

### 1. Inventory Management

- Real-time inventory updates
- Defective inventory tracking
- Serial/lot number management
- Warehouse/bin location updates

### 2. Sales Order Processing

- Original order validation
- Replacement order generation
- Credit application to new orders
- Customer history updates

### 3. Purchase Order Processing

- Vendor return initiation
- Replacement order creation
- Vendor performance tracking

### 4. Accounts Receivable

- Credit memo generation
- Account balance updates
- Aging impact
- Payment application

### 5. Accounts Payable

- Debit memo generation
- Vendor account updates
- Payment adjustments

### 6. General Ledger

- Automated journal entries
- Revenue recognition adjustments
- Cost of goods sold adjustments
- Tax liability adjustments

## Business Rules Engine

### Return Eligibility Rules

1. **Time-based Rules**
   - Days from invoice for DOA (Dead on Arrival)
   - Warranty period validation
   - Return authorization expiration

2. **Item-based Rules**
   - Allow/disallow discarding
   - Allow/disallow repairing
   - Restocking fee applicability
   - Minimum restocking amount

3. **Customer/Vendor Rules**
   - Credit limit considerations
   - Return frequency limits
   - Special agreement overrides

### Charge Calculation Rules

1. **Restocking Fees**
   - Percentage of return value
   - Minimum fee amount
   - Item-specific overrides
   - Customer-specific exceptions

2. **Repair Charges**
   - Fixed amount per item
   - Labor plus parts
   - Warranty coverage rules

### Approval Workflow Rules

1. **Authorization Levels**
   - Return value thresholds
   - Exception approvals
   - Credit limit overrides

2. **Escalation Rules**
   - Time-based escalation
   - Value-based escalation
   - Exception routing

## Event Streams

### Core Events

1. **Return Events**
   - ReturnAuthorizationCreated
   - ReturnAuthorizationUpdated
   - ReturnAuthorizationCancelled
   - ReturnAuthorizationCompleted

2. **Receipt Events**
   - ReturnItemsReceived
   - ReceiptQuantityAdjusted
   - ItemConditionAssessed

3. **Shipment Events**
   - ReplacementShipmentCreated
   - SubstituteShipmentCreated
   - ShipmentCompleted

4. **Financial Events**
   - CreditMemoGenerated
   - DebitMemoGenerated
   - RestockingFeeApplied
   - RepairChargeApplied

## Reporting Requirements

### Operational Reports

1. **Return Status Reports**
   - Open returns by age
   - Pending receipts
   - Pending shipments
   - Awaiting completion

2. **Return Analysis**
   - Returns by reason code
   - Returns by product
   - Returns by customer/vendor
   - Return trends

### Financial Reports

1. **Return Impact Analysis**
   - Revenue impact
   - Margin impact
   - Cost recovery analysis

2. **Reconciliation Reports**
   - Credit memo reconciliation
   - Inventory adjustment reconciliation
   - GL posting reconciliation

## Performance Metrics

### Key Performance Indicators

1. **Operational KPIs**
   - Return processing time
   - Receipt to resolution time
   - First-time resolution rate
   - Return rate by product

2. **Financial KPIs**
   - Return cost as % of revenue
   - Credit memo accuracy
   - Cost recovery rate
   - Restocking fee collection rate

3. **Customer Service KPIs**
   - Customer satisfaction score
   - Repeat return rate
   - Authorization to receipt time

## Data Retention and Audit

### Audit Requirements

1. **Transaction Audit**
   - Complete change history
   - User action tracking
   - Approval trail
   - Document versioning

2. **Compliance Tracking**
   - Warranty compliance
   - Return policy adherence
   - Financial accuracy

### Data Retention Policies

1. **Active Data**
   - Open returns: Immediate access
   - Recent completions: 90 days quick access

2. **Archive Data**
   - Completed returns: 7 years
   - Supporting documents: 7 years
   - Audit trails: Permanent

## Exception Handling

### Common Exceptions

1. **Over-return Scenarios**
   - Quantity exceeds original
   - Value exceeds original
   - Duplicate return attempts

2. **Inventory Exceptions**
   - Insufficient stock for replacement
   - Missing substitute items
   - Warehouse capacity issues

3. **Financial Exceptions**
   - Credit limit exceeded
   - Pricing discrepancies
   - Tax calculation errors

### Resolution Procedures

1. **Automated Resolution**
   - Rule-based adjustments
   - Alternative item selection
   - Workflow rerouting

2. **Manual Intervention**
   - Exception queues
   - Approval workflows
   - Override procedures

## Configuration Management

### System Parameters

1. **Global Settings**
   - Default return windows
   - Standard restocking percentages
   - Approval thresholds

2. **Return Code Configuration**
   - Action definitions
   - Charge structures
   - Eligibility rules

3. **Integration Settings**
   - Module dependencies
   - Event routing rules
   - Synchronization parameters

## Security and Access Control

### Role-based Permissions

1. **Return Authorization**
   - Create authorization
   - Modify authorization
   - Cancel authorization
   - Approve exceptions

2. **Financial Processing**
   - Apply charges
   - Override fees
   - Generate credits
   - Post to GL

3. **System Administration**
   - Configure return codes
   - Set approval rules
   - Manage integrations

This business logic framework provides the foundation for implementing a comprehensive Return Merchandise Authorization system within the Accountex modular architecture, ensuring proper handling of returns while maintaining data integrity and financial accuracy across all integrated modules.
