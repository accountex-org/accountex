# Purchase Orders Business Logic

## Overview

The Purchase Orders application manages the complete lifecycle of purchase transactions with vendors, from initial quotes through order fulfillment and payment. This document describes the business logic requirements for implementing purchase order functionality within the Accountex modular architecture.

## Core Concepts

### Purchase Order States

1. **Quote** - Non-binding proposal from vendor
2. **Draft** - Purchase order being prepared
3. **Pending Approval** - Awaiting authorization
4. **Approved** - Authorized for execution
5. **Partially Received** - Some items delivered
6. **Received** - All items delivered
7. **Partially Invoiced** - Some items billed
8. **Invoiced** - Fully billed
9. **Closed** - Transaction complete
10. **Cancelled** - Order terminated
11. **On Hold** - Temporarily suspended

### Purchase Order Types

1. **Standard Purchase Order** - Regular one-time order
2. **Blanket Purchase Order** - Long-term agreement with multiple releases
3. **Recurring Purchase Order** - Template for periodic orders
4. **Drop Ship Order** - Direct vendor-to-customer shipment

## Business Rules

### Purchase Order Creation

#### Validation Rules

1. **Vendor Validation**
   - Vendor must exist and be active
   - Vendor cannot be on payment hold (unless override permission)
   - Vendor credit rating must be acceptable (configurable)

2. **Item Validation**
   - Items must be purchasable (not sales-only)
   - Kit items must have valid components
   - Non-stock items require description
   - Items must have valid unit of measure for purchasing

3. **Pricing Validation**
   - Unit price must be positive or zero (for samples)
   - Discount percentage cannot exceed maximum allowed
   - Total order value must be within authorization limits

4. **Warehouse Validation**
   - Destination warehouse must be active
   - Drop ship orders require valid customer shipping address
   - Transit warehouse required for inter-warehouse transfers

#### Business Logic

```elixir
defmodule PurchaseOrders.Logic.CreateOrder do
  # Events
  defmodule PurchaseOrderCreated do
    defstruct [:order_id, :vendor_id, :order_date, :items, :total, :type]
  end

  # Aggregates
  defmodule PurchaseOrder do
    # State includes: status, vendor_id, items, totals, dates
    
    def execute(order, %CreatePurchaseOrder{} = command) do
      with :ok <- validate_vendor(command.vendor_id),
           :ok <- validate_items(command.items),
           :ok <- validate_authorization(command.total),
           :ok <- validate_warehouse(command.warehouse_id) do
        
        %PurchaseOrderCreated{
          order_id: command.order_id,
          vendor_id: command.vendor_id,
          order_date: command.order_date,
          items: calculate_line_items(command.items),
          total: calculate_total(command.items)
        }
      end
    end
  end
end
```

### Purchase Order Amendment

#### Amendment Restrictions

1. **Status Restrictions**
   - Cannot amend if status is Closed or Cancelled
   - Cannot reduce quantity below received amount
   - Cannot change vendor after partial receipt
   - Cannot change warehouse after shipment initiated

2. **Item Changes**
   - Can add new items unless fully received
   - Can increase quantities unless invoiced
   - Can modify prices if not invoiced
   - Cannot delete items with received quantities

3. **Audit Requirements**
   - All amendments must be tracked with timestamp and user
   - Original values must be preserved
   - Reason for amendment may be required

### Purchase Order Cancellation

#### Cancellation Rules

1. **Full Cancellation**
   - Allowed only if no items received
   - Must void any advance payments
   - Updates vendor purchase statistics
   - May require cancellation reason

2. **Partial Cancellation**
   - Cancel remaining open quantities
   - Maintain history of received items
   - Adjust commitment values
   - Update inventory projections

3. **Lost Purchase Order Tracking**
   - Option to save cancelled orders as "lost"
   - Track cancellation reasons
   - Available for reporting and analysis

### Receiving Process

#### Receipt Validation

1. **Quantity Validation**
   - Cannot exceed ordered quantity (unless over-receipt allowed)
   - Must respect minimum receipt quantity
   - Serial/lot numbers required for tracked items

2. **Quality Control**
   - May require inspection before acceptance
   - Supports partial acceptance/rejection
   - Defective items tracked separately

3. **Inventory Impact**
   - Updates on-hand quantities
   - Triggers reorder point calculations
   - Updates average costs
   - Creates inventory transactions

#### Three-Way Matching

```elixir
defmodule PurchaseOrders.Logic.ThreeWayMatch do
  def validate_invoice(purchase_order, receipt, invoice) do
    with :ok <- match_quantities(purchase_order, receipt, invoice),
         :ok <- match_prices(purchase_order, invoice),
         :ok <- validate_tolerances(purchase_order, receipt, invoice) do
      {:ok, :matched}
    else
      {:error, :quantity_mismatch} -> require_approval(:quantity_variance)
      {:error, :price_mismatch} -> require_approval(:price_variance)
      {:error, :tolerance_exceeded} -> require_manual_review()
    end
  end
end
```

### Blanket Purchase Orders

#### Blanket Order Rules

1. **Agreement Terms**
   - Valid date range required
   - Maximum total value
   - Minimum/maximum release amounts
   - Delivery schedule constraints

2. **Release Management**
   - Each release creates linked purchase order
   - Tracks cumulative released amount
   - Prevents exceeding blanket total
   - Monitors expiration dates

3. **Price Protection**
   - Fixed pricing for agreement period
   - Volume discount tiers
   - Price adjustment clauses

### Recurring Purchase Orders

#### Recurrence Patterns

1. **Frequency Options**
   - Daily, Weekly, Monthly, Quarterly, Annually
   - Custom intervals
   - Business days only option
   - Holiday exclusions

2. **Generation Rules**
   - Advance generation period
   - Automatic approval option
   - Quantity adjustment formulas
   - Seasonal variations

### Drop Shipping

#### Drop Ship Coordination

1. **Order Linking**
   - Links to customer sales order
   - Maintains margin visibility
   - Coordinates delivery dates
   - Synchronizes status updates

2. **Vendor Communication**
   - Blind shipping (hide pricing)
   - Custom packing slips
   - Direct shipping instructions
   - Tracking information relay

### Advanced Billing (Prepayments)

#### Prepayment Rules

1. **Payment Types**
   - Deposits on order
   - Progress payments
   - Full prepayment
   - Milestone-based

2. **Application Logic**
   - Apply to receipts
   - Match to invoices
   - Handle overpayments
   - Process refunds

## Integration Points

### Inventory Management

1. **Availability Checking**
   - Current on-hand quantities
   - Committed quantities
   - In-transit quantities
   - Projected availability dates

2. **Reorder Processing**
   - Automatic reorder point monitoring
   - Economic order quantity calculations
   - Lead time management
   - Safety stock maintenance

### Accounts Payable

1. **Invoice Processing**
   - Purchase order matching
   - Approval workflows
   - Payment term application
   - Discount calculations

2. **Payment Integration**
   - Payment authorization
   - Check/EFT generation
   - Remittance advice
   - Payment application

### Sales Orders (Drop Ship)

1. **Order Synchronization**
   - Status updates
   - Shipment notifications
   - Inventory availability
   - Margin protection

### General Ledger

1. **Accrual Entries**
   - Goods received not invoiced
   - Prepaid expenses
   - Purchase commitments

## Workflow Management

### Approval Workflows

```elixir
defmodule PurchaseOrders.Workflows.Approval do
  defmodule ApprovalRequested do
    defstruct [:order_id, :amount, :approver_id, :reason]
  end
  
  defmodule ApprovalGranted do
    defstruct [:order_id, :approver_id, :timestamp, :comments]
  end
  
  def request_approval(order) do
    cond do
      order.total > 100_000 -> require_cfo_approval(order)
      order.total > 50_000 -> require_director_approval(order)
      order.total > 10_000 -> require_manager_approval(order)
      true -> auto_approve(order)
    end
  end
end
```

### Document Management

1. **Attachment Types**
   - Purchase orders
   - Vendor quotes
   - Receipts/packing slips
   - Invoices
   - Quality certificates

2. **Document Workflow**
   - Version control
   - Approval chains
   - Distribution rules
   - Retention policies

## Event Streams

### Core Events

```elixir
# Order Lifecycle
PurchaseOrderCreated
PurchaseOrderAmended
PurchaseOrderApproved
PurchaseOrderRejected
PurchaseOrderCancelled
PurchaseOrderCompleted

# Receiving Events
GoodsReceived
GoodsInspected
GoodsAccepted
GoodsRejected
ReceiptCorrected

# Billing Events
InvoiceReceived
InvoiceMatched
InvoiceApproved
PaymentScheduled
PaymentCompleted

# Blanket Order Events
BlanketOrderCreated
ReleaseGenerated
BlanketOrderExpired

# Recurring Events
RecurringTemplateCreated
RecurringOrderGenerated
RecurrencePatternUpdated
```

## Reporting Requirements

### Operational Reports

1. **Order Status**
   - Open orders by vendor
   - Overdue deliveries
   - Pending approvals
   - Order aging

2. **Receipt Reports**
   - Goods received not invoiced
   - Receipt variances
   - Quality rejections
   - Receiving efficiency

3. **Performance Metrics**
   - Vendor on-time delivery
   - Price variance analysis
   - Order cycle time
   - Approval bottlenecks

### Financial Reports

1. **Commitment Reporting**
   - Outstanding purchase commitments
   - Accrued liabilities
   - Prepaid balances
   - Cash flow projections

2. **Spend Analysis**
   - Vendor spend ranking
   - Category analysis
   - Price trend analysis
   - Discount utilization

## Security and Compliance

### Access Control

1. **Role-Based Permissions**
   - Create/modify orders
   - Approve orders (by amount)
   - Receive goods
   - Process invoices
   - Override validations

2. **Segregation of Duties**
   - Order creation vs approval
   - Receipt vs invoice approval
   - Payment authorization

### Audit Trail

1. **Transaction Logging**
   - All state changes
   - User actions
   - System modifications
   - Integration events

2. **Compliance Features**
   - Document retention
   - Approval documentation
   - Variance explanations
   - Policy enforcement

## Performance Optimization

### Caching Strategies

1. **Vendor Data**
   - Payment terms
   - Default addresses
   - Approved item lists
   - Pricing agreements

2. **Inventory Data**
   - Available quantities
   - Reorder parameters
   - Lead times
   - Preferred vendors

### Batch Processing

1. **Recurring Generation**
   - Off-peak scheduling
   - Parallel processing
   - Error recovery
   - Notification batching

2. **Invoice Matching**
   - Automated matching rules
   - Exception queuing
   - Bulk approval processing

## Error Handling

### Validation Failures

1. **User Corrections**
   - Clear error messages
   - Suggested corrections
   - Validation bypass options
   - Supervisor overrides

2. **System Failures**
   - Transaction rollback
   - Compensation events
   - Retry mechanisms
   - Manual intervention queues

### Integration Failures

1. **Downstream Systems**
   - Queue failed events
   - Retry with backoff
   - Alternative processing
   - Manual reconciliation

2. **External Services**
   - Vendor portals
   - EDI connections
   - Payment gateways
   - Shipping providers

   # Purchase Orders Business Logic

## Overview

The Purchase Orders application manages the procurement lifecycle from requisition through receipt and payment. It handles vendor relationships, inventory replenishment, cost management, and integration with other modules in the Accountex system.

## Core Domain Concepts

### Purchase Order States

1. **Draft** - Initial creation, fully editable
2. **Quote** - Pricing request from vendor, not yet committed
3. **Approved** - Authorized for ordering
4. **Sent** - Transmitted to vendor
5. **Partially Received** - Some items delivered
6. **Fully Received** - All items delivered
7. **Closed** - Completed and paid
8. **Cancelled** - Terminated before completion

### Blanket Purchase Order States

1. **Active** - Available for releases
2. **Expired** - Past validity date
3. **Fully Released** - All quantities consumed
4. **Cancelled** - Terminated

## Aggregates

### PurchaseOrder

Core aggregate managing the purchase order lifecycle.

**Attributes:**

- `id` - Unique identifier
- `number` - Human-readable PO number
- `vendor_id` - Reference to vendor
- `status` - Current state
- `order_date` - Date of creation
- `requested_date` - Expected delivery date
- `warehouse_id` - Default receiving location
- `buyer_id` - Purchasing agent
- `payment_terms` - Payment conditions
- `currency` - Transaction currency
- `exchange_rate` - Currency conversion rate
- `tax_applicable` - Tax calculation flag
- `freight_terms` - Shipping arrangements
- `line_items` - Collection of ordered items
- `total_amount` - Calculated total
- `notes` - Internal/external remarks

### PurchaseOrderLineItem

**Attributes:**

- `id` - Unique identifier
- `item_id` - Inventory item reference
- `description` - Item description (can override)
- `quantity_ordered` - Amount requested
- `quantity_received` - Amount delivered
- `quantity_cancelled` - Amount cancelled
- `unit_of_measure` - Purchasing UOM
- `unit_price` - Cost per unit
- `discount_percentage` - Line discount
- `tax_applicable` - Item taxability
- `warehouse_id` - Specific receiving location
- `reference_account_id` - GL posting account

### BlanketPurchaseOrder

Long-term purchase agreement for recurring purchases.

**Attributes:**

- `id` - Unique identifier
- `number` - Blanket PO number
- `vendor_id` - Supplier reference
- `valid_until` - Expiration date
- `total_quantity` - Committed amount
- `released_quantity` - Amount consumed
- `line_items` - Covered items
- `default_terms` - Standard conditions

### Receipt

Records delivery of ordered goods.

**Attributes:**

- `id` - Unique identifier
- `receipt_number` - Document number
- `purchase_order_id` - Source PO
- `receipt_date` - Delivery date
- `warehouse_id` - Receiving location
- `line_items` - Received items
- `freight_amount` - Shipping costs

### LandedCostAccrual

Allocates additional procurement costs.

**Attributes:**

- `id` - Unique identifier
- `transaction_number` - Document reference
- `receipt_id` - Associated receipt
- `vendor_id` - Cost vendor
- `amount` - Total landed cost
- `allocation_method` - Distribution logic
- `allocations` - Item-level amounts

## Commands

### Purchase Order Creation

#### CreatePurchaseOrderByVendor

```elixir
defmodule CreatePurchaseOrderByVendor do
  @required [:vendor_id, :order_date, :buyer_id]
  @optional [:warehouse_id, :payment_terms, :currency, :notes]
  
  # Validations:
  # - Vendor must be active
  # - Vendor must have valid credit standing
  # - Buyer must have purchasing authority
  # - Warehouse must be active if specified
end
```

#### CreatePurchaseOrderByItem

```elixir
defmodule CreatePurchaseOrderByItem do
  @required [:item_ids, :quantities]
  
  # Business Rules:
  # - Select best vendor based on price/availability
  # - Group items by vendor
  # - Create separate POs per vendor
  # - Apply vendor-specific terms
end
```

#### CreatePurchaseOrderBySalesOrder

```elixir
defmodule CreatePurchaseOrderBySalesOrder do
  @required [:sales_order_id]
  
  # Business Rules:
  # - Only for drop-ship or special orders
  # - Link PO to SO for tracking
  # - Use customer shipping address if drop-ship
  # - Maintain margin requirements
end
```

#### CreatePurchaseOrderByReorderPoint

```elixir
defmodule CreatePurchaseOrderByReorderPoint do
  @required [:warehouse_id]
  
  # Business Rules:
  # - Identify items below reorder point
  # - Calculate economic order quantities
  # - Group by preferred vendor
  # - Consider lead times
end
```

### Purchase Order Management

#### AmendPurchaseOrder

```elixir
defmodule AmendPurchaseOrder do
  @required [:purchase_order_id, :changes]
  
  # Validations:
  # - Cannot amend if goods received
  # - Cannot reduce quantities below received
  # - Must maintain audit trail
  # - May require re-approval
end
```

#### ApprovePurchaseOrder

```elixir
defmodule ApprovePurchaseOrder do
  @required [:purchase_order_id, :approver_id]
  
  # Business Rules:
  # - Check approval authority limits
  # - Validate budget availability
  # - Convert quote to order
  # - Update inventory on-order quantities
end
```

#### CancelPurchaseOrder

```elixir
defmodule CancelPurchaseOrder do
  @required [:purchase_order_id, :reason]
  
  # Validations:
  # - Cannot cancel if partially received
  # - Must cancel all backorders
  # - Reverse on-order quantities
  # - Notify vendor if sent
end
```

### Receipt Processing

#### ReceiveGoods

```elixir
defmodule ReceiveGoods do
  @required [:purchase_order_id, :receipt_date, :line_items]
  
  # Business Rules:
  # - Validate against PO quantities
  # - Allow over-receipt with warning
  # - Update inventory on-hand
  # - Decrease on-order quantities
  # - Generate accounting entries if accrual enabled
  # - Trigger quality inspection if required
end
```

#### AssignSerialNumbers

```elixir
defmodule AssignSerialNumbers do
  @required [:receipt_id, :item_id, :serial_numbers]
  
  # Validations:
  # - Serial numbers must be unique
  # - Count must match quantity
  # - Format must match pattern
end
```

#### AssignLotNumbers

```elixir
defmodule AssignLotNumbers do
  @required [:receipt_id, :item_id, :lot_details]
  
  # Includes:
  # - Vendor lot number
  # - Internal lot number
  # - Expiration dates
  # - Quality certificates
end
```

### Landed Cost Management

#### AccrueLandedCost

```elixir
defmodule AccrueLandedCost do
  @required [:receipt_id, :vendor_id, :amount, :allocation_method]
  
  # Allocation Methods:
  # - By weight
  # - By value
  # - By quantity
  # - User-defined
  
  # Business Rules:
  # - Must allocate full amount
  # - Update inventory costs
  # - Create liability accrual
end
```

#### ReverseLandedCostAccrual

```elixir
defmodule ReverseLandedCostAccrual do
  @required [:accrual_id, :reversal_date]
  
  # Used when posting actual invoice
  # Maintains audit trail
end
```

### Blanket Purchase Orders

#### CreateBlanketPurchaseOrder

```elixir
defmodule CreateBlanketPurchaseOrder do
  @required [:vendor_id, :valid_until, :line_items]
  
  # Business Rules:
  # - Establish long-term pricing
  # - Set release limits
  # - Define authorized releasers
end
```

#### ReleaseBlanketPurchaseOrder

```elixir
defmodule ReleaseBlanketPurchaseOrder do
  @required [:blanket_po_id, :release_quantities]
  
  # Validations:
  # - Cannot exceed unreleased quantities
  # - Must be before expiration date
  # - Creates regular PO
  # - Updates blanket PO balances
end
```

### Backorder Management

#### CancelBackorder

```elixir
defmodule CancelBackorder do
  @required [:purchase_order_ids]
  @optional [:line_item_ids]
  
  # Options:
  # - Cancel entire PO
  # - Cancel specific lines
  # - Cancel remaining quantities
  
  # Updates on-order quantities
end
```

## Events

### Purchase Order Events

```elixir
defmodule PurchaseOrderCreated do
  @fields [:id, :number, :vendor_id, :total_amount, :created_by]
end

defmodule PurchaseOrderApproved do
  @fields [:id, :approved_by, :approved_at]
end

defmodule PurchaseOrderSent do
  @fields [:id, :sent_to, :sent_via, :sent_at]
end

defmodule PurchaseOrderAmended do
  @fields [:id, :changes, :amended_by, :reason]
end

defmodule PurchaseOrderCancelled do
  @fields [:id, :cancelled_by, :reason, :cancelled_at]
end
```

### Receipt Events

```elixir
defmodule GoodsReceived do
  @fields [:receipt_id, :purchase_order_id, :items, :received_by]
end

defmodule ReceiptCorrected do
  @fields [:receipt_id, :corrections, :corrected_by]
end

defmodule SerialNumbersAssigned do
  @fields [:receipt_id, :item_id, :serial_numbers]
end

defmodule LotNumbersAssigned do
  @fields [:receipt_id, :item_id, :lot_details]
end
```

### Landed Cost Events

```elixir
defmodule LandedCostAccrued do
  @fields [:id, :receipt_id, :amount, :allocations]
end

defmodule LandedCostReversed do
  @fields [:accrual_id, :reversal_amount, :invoice_id]
end
```

### Blanket PO Events

```elixir
defmodule BlanketPurchaseOrderCreated do
  @fields [:id, :vendor_id, :valid_until, :total_commitment]
end

defmodule BlanketPurchaseOrderReleased do
  @fields [:blanket_po_id, :purchase_order_id, :released_amount]
end

defmodule BlanketPurchaseOrderExpired do
  @fields [:id, :expiration_date, :unreleased_amount]
end
```

## Business Rules

### Pricing Hierarchy

When determining default unit price:

1. **Vendor-specific pricing** - Contracted rates
2. **Last received cost** - If within validity period
3. **Average cost** - Current inventory average
4. **Zero** - For new items without history

### Vendor Selection

For automatic vendor selection:

1. **Best price** - Lowest unit cost
2. **Preferred vendor** - Designated primary supplier
3. **Lead time** - Fastest delivery
4. **Minimum order** - Meets quantity requirements
5. **Payment terms** - Most favorable conditions

### Quantity Validations

- **Over-receipt tolerance** - Configurable percentage
- **Under-receipt** - Allowed with backorder creation
- **Reorder point** - Triggers when: On-hand + On-order ≤ Reorder point
- **Economic order quantity** - Optimal purchase quantity

### Tax Calculations

- Apply tax only when all conditions met:
  - Apply Tax checkbox marked
  - Tax code specified
  - Line item marked taxable
- Consider minimum/maximum taxable amounts
- Support tax-inclusive pricing

### Multi-Warehouse Handling

- Each line item can specify different warehouse
- Generate separate shipping instructions per warehouse
- Track quantities by warehouse
- Support warehouse transfers post-receipt

### Foreign Currency

- Lock exchange rate at order creation
- Calculate realized gains/losses on payment
- Support multi-currency vendors
- Maintain home currency reporting

## Integration Points

### Inventory Control

**Updates:**

- On-order quantities (PO creation/approval)
- On-hand quantities (receipt)
- Available quantities (receipt)
- Average costs (receipt with landed cost)
- Reorder points monitoring

**Validations:**

- Item existence and status
- Warehouse assignments
- Unit of measure conversions
- Serial/lot requirements

### Accounts Payable

**Triggers:**

- Voucher creation on receipt
- Accrued liability for landed costs
- Invoice matching
- Payment scheduling

**Data Flow:**

- Vendor balances
- Payment terms
- Credit limits
- Purchase history

### Sales Orders

**Linkages:**

- Drop-ship orders
- Special orders
- Back-to-back ordering
- Available-to-promise updates

### General Ledger

**Journal Entries:**

- Inventory receipts (if accrual-based)
- Landed cost accruals
- Purchase price variances
- Foreign currency adjustments

### Project Management

**Allocations:**

- Project-specific purchases
- Cost tracking
- Budget consumption
- Approval workflows

## Calculations

### Line Item Extension

```elixir
def calculate_line_extension(quantity, unit_price, discount_percent) do
  gross_amount = quantity * unit_price
  discount_amount = gross_amount * (discount_percent / 100)
  gross_amount - discount_amount
end
```

### Landed Cost Allocation

```elixir
def allocate_by_weight(total_cost, line_items) do
  total_weight = Enum.sum(line_items, & &1.weight * &1.quantity)
  
  Enum.map(line_items, fn item ->
    item_weight = item.weight * item.quantity
    allocation = (item_weight / total_weight) * total_cost
    {item.id, allocation}
  end)
end

def allocate_by_value(total_cost, line_items) do
  total_value = Enum.sum(line_items, & &1.extended_amount)
  
  Enum.map(line_items, fn item ->
    allocation = (item.extended_amount / total_value) * total_cost
    {item.id, allocation}
  end)
end
```

### Reorder Point Calculation

```elixir
def needs_reorder?(item, warehouse) do
  on_hand = get_on_hand_quantity(item, warehouse)
  on_order = get_on_order_quantity(item, warehouse)
  available = on_hand + on_order
  
  available <= item.reorder_point
end

def calculate_order_quantity(item) do
  if item.reorder_quantity > 0 do
    item.reorder_quantity
  else
    calculate_economic_order_quantity(item)
  end
end
```

## Workflow States

### Standard Purchase Order Flow

```
Draft → Approved → Sent → Partially Received → Fully Received → Closed
         ↓
      Cancelled
```

### Purchase Quote Flow

```
Quote → Approved (converts to PO) → [Standard PO Flow]
   ↓
Expired/Rejected
```

### Blanket PO Release Flow

```
Blanket PO → Release → Create PO → [Standard PO Flow]
           ↓
        Check Validity
           ↓
    Update Unreleased Qty
```

## Validation Rules

### Purchase Order Creation

1. **Vendor Validation**
   - Must be active
   - Must have valid tax ID
   - Credit limit not exceeded
   - No payment holds

2. **Item Validation**
   - Must be purchasable
   - Valid for specified warehouse
   - Correct unit of measure
   - Vendor item cross-reference exists

3. **Date Validation**
   - Request date ≥ Order date
   - Order date not in closed period
   - Valid until date > Current date (for blankets)

4. **Quantity Validation**
   - Positive quantities only
   - Meets vendor minimum order
   - Within maximum order limits
   - Multiple of order increment

### Receipt Validation

1. **Quantity Checks**
   - Cannot exceed PO quantity + tolerance
   - Must be positive
   - Serial count matches quantity
   - Lot quantities sum to total

2. **Date Validation**
   - Receipt date ≥ PO date
   - Not in closed period
   - Before expiration (for lot-controlled)

3. **Warehouse Validation**
   - Warehouse is active
   - Item allowed in warehouse
   - Bin location exists
   - Sufficient capacity

## Error Handling

### Common Validation Errors

- `VendorInactive` - Vendor is not available for transactions
- `InsufficientCredit` - Exceeds vendor credit limit
- `ItemNotPurchasable` - Item not set up for purchasing
- `InvalidWarehouse` - Warehouse not authorized for item
- `QuantityExceedsOrdered` - Receipt exceeds PO quantity
- `BlanketPOExpired` - Past validity date
- `DuplicatePONumber` - PO number already exists
- `PeriodClosed` - Transaction date in closed period

### Business Rule Violations

- `BelowMinimumOrder` - Order quantity below vendor minimum
- `ExceedsApprovalLimit` - Amount exceeds approver authority
- `BudgetExceeded` - Insufficient budget funds
- `CannotAmendReceivedPO` - PO has receipts
- `CannotCancelPartiallyReceived` - Must void receipts first

## Performance Considerations

### Indexing Requirements

- Purchase order number (unique)
- Vendor ID + Status
- Order date + Status
- Warehouse + Item (for reorder point)
- Blanket PO + Valid until date

### Caching Strategy

- Vendor terms and pricing
- Item reorder parameters
- Warehouse availability
- Exchange rates (daily)
- Tax rates

### Batch Operations

- Reorder point processing
- Blanket PO expiration
- Backorder cancellation
- Mass approval workflow

## Audit Requirements

### Required Audit Fields

- Created by/at
- Modified by/at
- Approved by/at
- Cancelled by/at/reason
- Amendment history
- Price change justification

### Change Tracking

All changes to critical fields must be logged:

- Quantities
- Prices
- Payment terms
- Delivery dates
- Vendor changes
- Warehouse changes

## Security Considerations

### Role-Based Permissions

**Buyer Role:**

- Create/amend purchase orders
- Cannot approve own orders
- View vendor information
- Generate reorder suggestions

**Approver Role:**

- Approve within limit
- Override price warnings
- Cancel orders
- View budget status

**Receiver Role:**

- Record receipts
- Assign serial/lot numbers
- Report discrepancies
- Cannot modify PO

**Manager Role:**

- All permissions
- Configure approval limits
- Override validations
- Access audit logs

### Data Security

- Vendor payment information encryption
- Price visibility restrictions
- Competitive bid confidentiality
- Document access control

# Purchase Orders Business Logic

## Overview

The Purchase Orders application manages the procurement lifecycle from requisition through receipt of goods. It integrates with Inventory Control, Accounts Payable, and other modules to provide comprehensive purchasing management.

## Core Domain Concepts

### Purchase Order States

- **Draft**: Initial state, editable
- **Submitted**: Sent to vendor, locked for editing
- **Partially Received**: Some items received
- **Fully Received**: All items received
- **Closed**: Order completed
- **Cancelled**: Order cancelled before completion

### Purchase Quote States

- **Draft**: Initial quote state
- **Pending Approval**: Awaiting approval
- **Approved**: Ready for conversion to PO
- **Rejected**: Quote rejected
- **Converted**: Converted to purchase order

### Blanket Purchase Order States

- **Active**: Available for releases
- **Partially Released**: Some quantity released
- **Fully Released**: All quantity released
- **Expired**: Past expiration date
- **Closed**: Manually closed

## Business Rules

### Purchase Order Creation

#### Validation Rules

1. **Vendor Validation**
   - Vendor must be active
   - Vendor currency must match PO currency
   - Credit limit check if configured
   - Required fields: vendor number, company name

2. **Line Item Validation**
   - Item must be configured for purchase orders
   - Quantity must be positive
   - Unit cost validation against vendor pricing
   - Warehouse must be valid and active
   - Tax code must be valid if taxable

3. **Order Total Validation**
   - Minimum order amount check
   - Maximum order amount check against approval limits
   - Budget validation if budget control enabled

#### Calculation Rules

1. **Line Item Calculations**

   ```
   Line Subtotal = Quantity × Unit Cost
   Discount Amount = Line Subtotal × (Discount % / 100)
   Line Total = Line Subtotal - Discount Amount
   ```

2. **Tax Calculations**

   ```
   Taxable Amount = Sum(Taxable Line Totals)
   Tax Amount = Taxable Amount × Tax Rate
   ```

3. **Order Total Calculation**

   ```
   Subtotal = Sum(All Line Totals)
   Total Tax = Sum(All Tax Amounts)
   Order Total = Subtotal + Total Tax + Freight Amount
   ```

### Vendor Pricing Logic

#### Price Determination Hierarchy

1. Contract pricing (if exists)
2. Quantity-based pricing tiers
3. Vendor-specific item pricing
4. Last received cost (if configured)
5. Standard cost
6. Default to manual entry

#### Discount Application

1. Line-level discounts applied first
2. Vendor discount applied if no line discount
3. Volume discounts based on quantity breaks
4. Early payment discounts tracked separately

### Receiving Goods

#### Receipt Validation

1. **Pre-Receipt Checks**
   - PO must be in submitted state
   - Receiving warehouse must be active
   - User must have receiving permissions

2. **Receipt Processing**
   - Allow over-receipt based on tolerance settings
   - Serial/lot number required for tracked items
   - Bin location required if warehouse uses bins

3. **Quantity Validation**

   ```
   Available to Receive = Ordered Qty - Previously Received Qty
   Over-Receipt Allowed = Available to Receive × (1 + Tolerance %)
   ```

#### Inventory Updates

1. **On Receipt**
   - Increase on-hand quantity
   - Update available quantity
   - Record in inventory transaction log
   - Update last received cost

2. **Cost Updates**
   - Update average cost if method is average
   - Update FIFO/LIFO layers if applicable
   - Recalculate weighted average cost

### Receipt Cancellation

#### Cancellation Rules

1. **Validation**
   - Receipt must not be invoiced
   - Inventory must be available for reversal
   - Serial/lot items must be available

2. **Reversal Processing**
   - Reverse inventory quantities
   - Reverse cost updates
   - Create cancellation document
   - Update PO status

### Landed Cost Accrual

#### Accrual Calculation

1. **Cost Allocation Methods**
   - By weight
   - By volume
   - By value
   - By quantity
   - Equal distribution

2. **Allocation Formula**

   ```
   Item Allocation = Total Landed Cost × (Item Basis / Total Basis)
   Unit Landed Cost = Item Allocation / Item Quantity
   ```

3. **Cost Update**
   - Add landed cost to item cost
   - Update inventory valuation
   - Create GL entries for accrual

### Blanket Purchase Orders

#### Release Rules

1. **Quantity Validation**

   ```
   Available for Release = Blanket Qty - Released Qty
   Release Qty ≤ Available for Release
   ```

2. **Date Validation**
   - Release date must be within blanket PO period
   - Cannot release from expired blanket PO

3. **Price Protection**
   - Released POs inherit blanket pricing
   - Discounts locked at blanket level

### Purchase Quote Management

#### Quote Conversion Rules

1. **Approval Requirements**
   - Quote must be in approved state
   - Approval hierarchy must be satisfied
   - Budget check if required

2. **Conversion Process**
   - Create PO with quote reference
   - Lock quote from further changes
   - Inherit all quote terms and conditions
   - Maintain audit trail

### Multi-Currency Processing

#### Exchange Rate Application

1. **Rate Determination**
   - Use transaction date rate
   - Allow manual rate override
   - Track rate variance

2. **Conversion Calculations**

   ```
   Home Currency Amount = Foreign Amount × Exchange Rate
   Rate Variance = Actual Rate - Standard Rate
   ```

## Workflows

### Standard Purchase Order Workflow

1. Create purchase requisition (optional)
2. Convert to purchase order
3. Apply approvals if required
4. Submit to vendor
5. Receive goods (partial or full)
6. Match with invoice
7. Close order

### Blanket Purchase Order Workflow

1. Negotiate blanket agreement
2. Create blanket PO
3. Release individual POs as needed
4. Receive against released POs
5. Monitor blanket utilization
6. Close or renew blanket

### Purchase Quote Workflow

1. Request quote from vendor
2. Enter quote details
3. Compare multiple quotes
4. Select and approve quote
5. Convert to purchase order
6. Follow standard PO workflow

## Integration Points

### Inventory Control Integration

- Update quantities on receipt
- Cost updates and recalculations
- Warehouse and bin management
- Serial/lot tracking

### Accounts Payable Integration

- Accrued liabilities on receipt
- Three-way matching (PO-Receipt-Invoice)
- Vendor payment terms
- 1099 tracking

### General Ledger Integration

- Inventory asset updates
- Accrued liability entries
- Landed cost accruals
- Purchase price variance

### Sales Order Integration

- Drop-ship purchase orders
- Back-to-back ordering
- Available-to-promise updates

## Event Streams

### Purchase Order Events

- `PurchaseOrderCreated`
- `PurchaseOrderSubmitted`
- `PurchaseOrderModified`
- `PurchaseOrderCancelled`
- `PurchaseOrderClosed`

### Receipt Events

- `GoodsReceived`
- `ReceiptCancelled`
- `OverReceiptApproved`
- `ReceiptReturned`

### Blanket PO Events

- `BlanketPOCreated`
- `BlanketPOReleased`
- `BlanketPOExpired`
- `BlanketPOClosed`

### Quote Events

- `PurchaseQuoteCreated`
- `PurchaseQuoteApproved`
- `PurchaseQuoteRejected`
- `PurchaseQuoteConverted`

## Compliance and Controls

### Approval Hierarchies

1. **Amount-Based Approvals**
   - Define approval limits by user/role
   - Escalation for amounts exceeding limits
   - Multi-level approval chains

2. **Category-Based Approvals**
   - Different approvers by item category
   - Capital vs. expense approvals
   - Department-specific approvals

### Audit Requirements

1. **Change Tracking**
   - All modifications logged
   - Before/after values captured
   - User and timestamp recorded

2. **Document Retention**
   - Cancelled documents retained
   - Complete audit trail maintained
   - Supporting documents linked

### Segregation of Duties

1. **Role Separation**
   - Requisitioner cannot approve own request
   - Receiver cannot modify PO
   - Separate invoice matching role

2. **Override Controls**
   - Documented override reasons
   - Additional approval for overrides
   - Exception reporting

## Performance Optimization

### Caching Strategies

- Vendor pricing matrices
- Tax rate tables
- Exchange rates
- Approval hierarchies

### Batch Processing

- Bulk receipt processing
- Mass PO generation from requisitions
- Scheduled blanket releases
- Automated reorder point processing

### Query Optimization

- Indexed vendor and item lookups
- Optimized backorder queries
- Efficient three-way matching
- Pre-calculated PO summaries

## Reporting Requirements

### Operational Reports

- Open purchase orders
- Backorder report
- Receipt history
- Vendor performance

### Financial Reports

- Accrued liabilities
- Purchase price variance
- Landed cost analysis
- Commitment reporting

### Analytical Reports

- Spend analysis by vendor
- Category spend trends
- Savings opportunities
- Vendor scorecards

## Data Retention

### Active Data

- Open purchase orders: Immediate access
- Recent receipts: 90 days online
- Active vendor records: Always available

### Archive Strategy

- Closed POs: Archive after 1 year
- Historical receipts: Archive after 2 years
- Cancelled documents: Archive after 90 days

### Purge Policies

- Archived data: Retain 7 years
- Audit logs: Retain 10 years
- Supporting documents: Follow legal requirements

## Exception Handling

### Over-Receipt Processing

1. Check tolerance settings
2. Require approval if over tolerance
3. Create exception report entry
4. Allow with documentation

### Price Variance Handling

1. Calculate variance from expected price
2. Flag if exceeds threshold
3. Route for approval if required
4. Track for analysis

### Expedite Processing

1. Mark orders as expedited
2. Send notifications to relevant parties
3. Track expedite fees
4. Monitor on-time delivery

## Security Considerations

### Access Controls

- Role-based permissions
- Vendor-specific restrictions
- Amount-based limitations
- Warehouse access controls

### Data Protection

- Encrypt sensitive vendor data
- Mask payment information
- Secure document attachments
- Audit data access

### Fraud Prevention

- Duplicate PO detection
- Unusual pattern detection
- Vendor verification
- Payment validation

# Purchase Orders Logic

## Overview

The Purchase Orders application manages the procurement process, vendor relationships, and inventory acquisition. It integrates with Inventory Control, Accounts Payable, Manufacturing, and Return to Vendor Authorization modules to provide comprehensive purchase order management capabilities.

## Core Domain Entities

### Vendor

#### Attributes

- **Vendor Number**: Unique identifier (up to 20 alphanumeric characters)
- **Vendor Name**: Legal business name (required)
- **Status**: Active/Inactive/One-Time
- **Type**: Regular vendor or subcontractor
- **Contact Information**: Multiple contacts with roles
- **Addresses**: Remit To, Order From, Ship From locations
- **Payment Terms**: Default pay code and credit limits
- **Tax Information**: Tax ID numbers and exemption status
- **Purchasing Preferences**: Minimum order amounts, lead times
- **GL Accounts**: Default expense and prepaid accounts
- **Currency**: Transaction currency for multi-currency support

#### Business Rules

- Vendors with existing transactions cannot be deleted
- Inactive vendors cannot be used in new transactions
- One-time vendors are automatically purged after specified periods
- Maximum check amounts enforce payment controls
- Credit limits trigger warnings or blocks on new orders

### Inventory Item

#### Attributes

- **Item Number**: Unique identifier (up to 30 alphanumeric characters)
- **Description**: Standard and foreign language descriptions
- **Type**: Stock, non-stock, service, kit, or lot-controlled
- **Warehouses**: Multiple warehouse assignments with bins
- **Pricing**: Unit price, special prices, multi-level pricing
- **Costing**: Cost method (Average, FIFO, LIFO, Specific ID)
- **Quantities**: On-hand, on-order, allocated, in-transit
- **Reorder Parameters**: Reorder point, reorder quantity, safety stock
- **Vendor Assignments**: Default and alternate vendors
- **Units of Measure**: Stock, purchase, and sales units
- **Tax Status**: Taxable/non-taxable designation

#### Business Rules

- Cost method cannot be changed after initial setup
- Negative quantity controls for drop shipments
- Kit items may require prebuild before shipment
- Lot-controlled items require lot number tracking
- Serialized items require unique serial number tracking
- Decimal places for quantities cannot be decreased

### Purchase Order

#### States

- **Draft**: Initial creation, fully editable
- **Submitted**: Sent to vendor, limited edits allowed
- **Partially Received**: Some items received
- **Fully Received**: All items received
- **Closed**: Order completed or manually closed
- **Cancelled**: Order cancelled before completion

#### Components

- **Header**: Vendor, dates, ship-to location, terms
- **Line Items**: Items, quantities, prices, discounts
- **Charges**: Freight, taxes, other charges
- **Receipts**: Partial or full receipt records
- **Returns**: RTV (Return to Vendor) transactions

#### Business Rules

- Cannot exceed vendor credit limits if enforced
- Must meet minimum order amounts if specified
- Lead time calculations affect expected delivery
- Price variance tolerances trigger warnings
- Approval workflows based on amount thresholds

## Core Workflows

### Vendor Management

#### Create Vendor

1. Validate unique vendor number
2. Set up remit-to address (required)
3. Configure payment terms and credit limits
4. Assign GL accounts for purchases
5. Set up tax exemption status if applicable
6. Configure electronic payment details if used
7. Establish vendor-item relationships

#### Update Vendor

1. Validate no breaking changes for existing transactions
2. Update contact and address information
3. Adjust credit limits and payment terms
4. Modify GL account assignments
5. Update vendor status (active/inactive)

### Inventory Management

#### Create Inventory Item

1. Validate unique item number
2. Select inventory type template if applicable
3. Assign to warehouses and bins
4. Set up costing method (one-time decision)
5. Configure reorder parameters
6. Establish vendor relationships
7. Set up pricing structures
8. Define units of measure

#### Inventory Valuation

1. Track costs by selected method
2. Calculate average costs for Average method
3. Maintain FIFO/LIFO cost layers
4. Track specific costs for serialized items
5. Handle cost variances on negative inventory

### Purchase Order Processing

#### Create Purchase Order

1. Select vendor and validate status
2. Check credit limits if enforced
3. Add line items with quantities and prices
4. Apply vendor discounts if applicable
5. Calculate taxes based on warehouse location
6. Determine freight charges
7. Set expected delivery dates

#### Receive Goods

1. Create receipt transaction
2. Update on-order quantities
3. Increase on-hand inventory
4. Calculate landed costs
5. Handle quantity variances
6. Process quality control if required
7. Update average costs or cost layers

#### Process Returns (RTV)

1. Select items to return
2. Create RTV transaction
3. Reduce on-hand inventory
4. Track return authorization numbers
5. Process vendor credits
6. Update inventory valuations

### Reorder Processing

#### Automatic Reorder

1. Identify items below reorder point
2. Group by preferred vendor
3. Calculate order quantities
4. Consider lead times
5. Apply minimum order requirements
6. Generate purchase orders

#### Manual Reorder

1. Review suggested orders
2. Adjust quantities as needed
3. Select alternate vendors if desired
4. Combine orders for efficiency
5. Apply bulk discounts

## Integration Points

### With Inventory Control

- Real-time inventory updates
- Cost calculation and valuation
- Warehouse transfers
- Physical count adjustments
- Lot and serial number tracking

### With Accounts Payable

- Vendor invoice matching
- Payment processing
- Credit memo handling
- 1099 reporting
- Cash flow management

### With Manufacturing

- Component purchasing
- Subcontractor management
- Work order materials
- Outside processing
- Make vs. buy decisions

### With Sales Orders

- Drop shipment processing
- Available quantity calculations
- Back-order management
- Cross-docking operations

## Business Rules Engine

### Vendor Rules

- Credit limit enforcement
- Payment term validation
- Minimum order requirements
- Preferred vendor selection
- Subcontractor restrictions

### Inventory Rules

- Negative quantity controls
- Reorder point triggers
- Safety stock maintenance
- Lot expiration tracking
- Serial number uniqueness

### Pricing Rules

- Quantity break pricing
- Contract pricing
- Promotional pricing periods
- Currency conversion
- Landed cost calculations

### Approval Rules

- Purchase order limits
- Vendor selection approval
- Price variance tolerance
- Emergency order handling
- Budget compliance

## Calculations

### Landed Cost

```
Landed Cost = Item Cost + (Freight × Allocation %) + 
              (Duties × Allocation %) + (Other Charges × Allocation %)
```

### Average Cost Update

```
New Average = ((Current Qty × Current Avg) + (Receipt Qty × Receipt Cost)) / 
              (Current Qty + Receipt Qty)
```

### Reorder Quantity

```
Reorder Qty = Max(Reorder Point - Available Qty + Safety Stock, 
                  Minimum Order Qty)
```

### Lead Time Calculation

```
Expected Date = Order Date + Vendor Lead Time + Transit Time + 
                Processing Time
```

## Event Streams

### Vendor Events

- VendorCreated
- VendorUpdated
- VendorDeactivated
- VendorCreditLimitChanged
- VendorPaymentTermsUpdated

### Inventory Events

- InventoryItemCreated
- InventoryItemUpdated
- ReorderPointReached
- CostMethodSelected
- InventoryValuationChanged

### Purchase Order Events

- PurchaseOrderCreated
- PurchaseOrderSubmitted
- GoodsReceived
- PurchaseOrderClosed
- ReturnToVendorInitiated

## Data Validation

### Vendor Validation

- Unique vendor number
- Valid tax identification
- Complete remit-to address
- Valid GL account assignments
- Proper payment terms

### Inventory Validation

- Unique item number
- Valid warehouse assignments
- Positive reorder parameters
- Consistent units of measure
- Valid cost method selection

### Order Validation

- Active vendor status
- Valid item selections
- Positive quantities
- Price reasonableness
- Delivery date logic

## Audit Requirements

### Vendor Changes

- Track all modifications
- Maintain change history
- Document approval chain
- Archive deleted records

### Inventory Adjustments

- Log all cost changes
- Track quantity movements
- Document count variances
- Maintain valuation history

### Purchase Transactions

- Complete order history
- Receipt documentation
- Return authorizations
- Price variance reports

## Performance Considerations

### Caching Strategy

- Vendor master data
- Inventory availability
- Pricing matrices
- Tax rates
- Reorder parameters

### Batch Processing

- Reorder point evaluation
- Cost recalculations
- Vendor statement generation
- Period-end closing

### Real-time Updates

- Inventory quantities
- Order status changes
- Receipt processing
- Cost adjustments

## Security and Compliance

### Access Controls

- Vendor creation/modification rights
- Purchase order approval limits
- Inventory adjustment permissions
- Cost modification restrictions
- Report access levels

### Compliance Requirements

- Tax reporting compliance
- 1099 vendor tracking
- Audit trail maintenance
- Document retention policies
- International trade regulations

## Reporting Requirements

### Operational Reports

- Open purchase orders
- Receiving log
- Vendor performance
- Reorder suggestions
- Price variances

### Financial Reports

- Inventory valuation
- Aged payables
- Cash requirements
- Cost analysis
- Landed cost details

### Analytical Reports

- Vendor analysis
- Purchase trends
- Lead time analysis
- Cost savings opportunities
- Inventory turnover

# Purchase Orders Business Logic

## Overview

The Purchase Orders application manages the complete procurement lifecycle from purchase requisition through goods receipt and vendor payment preparation. It integrates with Inventory Control, Accounts Payable, Sales Orders, and General Ledger modules to provide comprehensive purchasing management.

## Core Domain Concepts

### Purchase Order States

- **Draft**: Initial state, can be modified freely
- **Submitted**: Sent to vendor, modifications create revision history
- **Partially Received**: Some items received
- **Fully Received**: All items received
- **Completed**: All items received and invoiced
- **Cancelled**: Order cancelled before completion
- **On Hold**: Temporarily suspended

### Purchase Quote States

- **Draft**: Initial quote request
- **Pending Approval**: Awaiting approval
- **Approved**: Converted to Purchase Order
- **Rejected**: Quote not accepted
- **Expired**: Quote validity period passed

### Blanket Purchase Order States

- **Active**: Available for releases
- **Partially Released**: Some quantity released
- **Fully Released**: Maximum quantity/amount reached
- **Expired**: End date passed
- **Cancelled**: Terminated before completion

## Business Rules

### Purchase Order Creation

#### Manual Creation

1. **Vendor Selection**
   - Must have active vendor record
   - Validate credit limit if configured
   - Apply default payment terms from vendor record
   - Check for vendor holds or restrictions

2. **Line Item Processing**
   - Validate inventory item exists and is purchasable
   - Apply vendor-specific pricing if configured
   - Calculate extended amounts and taxes
   - Check for minimum order quantities
   - Validate against budget constraints if applicable

3. **Multi-Currency Support**
   - Convert foreign currency amounts at current exchange rate
   - Store both foreign and home currency values
   - Track exchange rate for future variance calculations

#### Creation by Item

1. **Item Selection**
   - Group items by preferred vendor
   - Consider vendor lead times
   - Apply quantity breakpoints for pricing
   - Check for substitute items if primary unavailable

2. **Automatic PO Generation**
   - Create separate POs per vendor
   - Consolidate items to minimize orders
   - Apply vendor-specific shipping methods
   - Calculate optimal order quantities

#### Creation by Sales Order

1. **Drop Shipment Processing**
   - Link PO lines to SO lines
   - Direct ship to customer address
   - Maintain SO-PO relationship for tracking
   - Update SO status when PO received

2. **Back-to-Back Orders**
   - Generate PO for out-of-stock SO items
   - Maintain quantity reservations
   - Update SO availability when goods received

#### Creation by Reorder Quantity

1. **Reorder Point Analysis**
   - Calculate items below reorder point
   - Consider safety stock requirements
   - Factor in lead times
   - Account for existing on-order quantities

2. **Economic Order Quantity**
   - Calculate optimal order quantities
   - Consider carrying costs
   - Apply vendor minimum requirements
   - Round to vendor packaging units

### Goods Receipt Processing

#### Standard Receipt

1. **Receipt Validation**
   - Match against open PO lines
   - Validate received quantities
   - Check for over-receipts if not allowed
   - Verify item specifications match

2. **Inventory Update**
   - Update on-hand quantities
   - Allocate to specific bins/locations
   - Process lot/serial numbers if required
   - Update average costs

3. **Accrual Processing**
   - Create liability accrual if configured
   - Track for three-way matching
   - Update PO receipt history
   - Generate receipt documentation

#### Partial Receipt

1. **Backorder Management**
   - Update remaining quantities
   - Optionally cancel remaining backorders
   - Recalculate expected delivery dates
   - Notify relevant parties

2. **Multiple Shipments**
   - Track receipt numbers
   - Maintain receipt history
   - Consolidate for invoicing
   - Handle split shipments

### Landed Cost Processing

#### Cost Allocation

1. **Allocation Methods**
   - By weight
   - By value
   - By quantity
   - Manual allocation

2. **Cost Distribution**
   - Distribute to received items
   - Update inventory valuations
   - Create GL distributions
   - Track for cost analysis

3. **Accrual Management**
   - Create landed cost accruals
   - Reverse when invoiced
   - Handle partial reversals
   - Maintain audit trail

### Purchase Quote Management

#### Quote Request

1. **Multi-Vendor RFQ**
   - Send to multiple vendors
   - Set response deadline
   - Track quote status
   - Compare responses

2. **Quote Evaluation**
   - Price comparison
   - Delivery time analysis
   - Payment terms evaluation
   - Quality/specification matching

#### Quote Approval

1. **Approval Workflow**
   - Route based on amount
   - Multiple approval levels
   - Approval delegation
   - Audit trail maintenance

2. **PO Generation**
   - Convert approved quote to PO
   - Maintain quote reference
   - Apply negotiated terms
   - Update vendor pricing

### Blanket Purchase Order Management

#### Blanket PO Creation

1. **Agreement Terms**
   - Set maximum quantity/amount
   - Define validity period
   - Establish pricing agreements
   - Set release restrictions

2. **Release Authorization**
   - Define authorized releasers
   - Set individual release limits
   - Require release approvals
   - Track cumulative releases

#### Release Processing

1. **Release Validation**
   - Check remaining quantity/amount
   - Verify within validity period
   - Validate releaser authorization
   - Apply release numbering

2. **Standard PO Generation**
   - Create PO from release
   - Link to blanket PO
   - Update blanket quantities
   - Maintain relationship

### Returns and Cancellations

#### Purchase Returns

1. **Return Authorization**
   - Generate RMA number
   - Specify return reason
   - Calculate restocking fees
   - Update inventory

2. **Credit Processing**
   - Create vendor credit memo
   - Adjust accounts payable
   - Update purchase history
   - Recalculate costs

#### Receipt Cancellation

1. **Cancellation Validation**
   - Verify not invoiced
   - Check inventory availability
   - Validate period constraints
   - Confirm authorization

2. **Reversal Processing**
   - Reverse inventory updates
   - Cancel accruals
   - Update PO status
   - Adjust costs

### Integration Points

#### Inventory Control

- Real-time quantity updates
- Cost calculation updates
- Bin/location management
- Lot/serial tracking

#### Accounts Payable

- Invoice matching
- Payment processing
- Vendor management
- Credit memo handling

#### Sales Orders

- Drop shipment coordination
- Back-to-back ordering
- Availability updates
- Customer notifications

#### General Ledger

- Accrual postings
- Cost variance entries
- Period-end adjustments
- Account distributions

### Compliance and Controls

#### Approval Hierarchies

1. **Amount-Based Approvals**
   - Define threshold levels
   - Escalation paths
   - Emergency approvals
   - Delegation management

2. **Department/Project Approvals**
   - Budget validation
   - Project authorization
   - Department limits
   - Cross-charging rules

#### Audit Requirements

1. **Change Tracking**
   - PO revision history
   - Price change audit
   - Quantity adjustments
   - Approval documentation

2. **Document Management**
   - Electronic signatures
   - Document attachments
   - Communication logs
   - Compliance certificates

### Reporting Requirements

#### Operational Reports

- Open purchase orders
- Receipts pending invoice
- Backorder analysis
- Vendor performance

#### Financial Reports

- Accrued liabilities
- Purchase commitments
- Cost variance analysis
- Budget vs. actual

#### Analytical Reports

- Vendor spend analysis
- Price trend analysis
- Lead time performance
- Quality metrics

### Period-End Processing

#### Closing Procedures

1. **Validation Checks**
   - Unmatched receipts
   - Open accruals
   - Pending approvals
   - Period cutoff

2. **Accrual Processing**
   - Generate recurring accruals
   - Reverse prior estimates
   - Post adjustments
   - Update commitments

3. **Roll Forward**
   - Carry forward open orders
   - Update period dates
   - Reset period counters
   - Archive closed transactions

### Multi-Company Considerations

#### Intercompany Purchases

1. **Intercompany POs**
   - Automatic SO generation
   - Transfer pricing
   - Consolidation elimination
   - Tax considerations

2. **Centralized Purchasing**
   - Shared vendor contracts
   - Consolidated ordering
   - Allocation to entities
   - Cross-entity approvals

### Advanced Features

#### EDI Integration

- Electronic PO transmission
- Automated acknowledgments
- ASN processing
- Invoice receipt

#### Vendor Portal

- Online PO viewing
- Shipment notifications
- Document upload
- Performance metrics

#### Mobile Capabilities

- Mobile receiving
- Approval on-the-go
- Barcode scanning
- Photo attachments

## Event Flows

### Standard Purchase Order Flow

1. Create/Import PO →
2. Submit to Vendor →
3. Receive Acknowledgment →
4. Receive Goods →
5. Record Receipt →
6. Accrue Liability →
7. Match Invoice →
8. Process Payment

### Blanket PO Release Flow

1. Create Blanket PO →
2. Authorize Releasers →
3. Create Release →
4. Generate Standard PO →
5. Process as Standard PO →
6. Update Blanket Quantities

### Purchase Return Flow

1. Identify Return Need →
2. Create Return Authorization →
3. Ship to Vendor →
4. Receive Credit Memo →
5. Update Inventory →
6. Adjust Payables

## Performance Considerations

### Optimization Requirements

- Bulk PO creation for high-volume scenarios
- Efficient receipt processing for warehouse operations
- Quick PO lookup and search capabilities
- Fast approval routing

### Scalability Needs

- Support for multiple warehouses
- High transaction volumes
- Multiple concurrent users
- Large vendor databases

## Security Requirements

### Access Controls

- PO creation authorization
- Approval limits by user
- Vendor maintenance restrictions
- Price override permissions

### Data Protection

- Vendor payment information
- Pricing agreements
- Contract terms
- Competitive information

# Purchase Orders Business Logic

## Overview

The Purchase Orders application manages the procurement lifecycle within Accountex, handling vendor relationships, purchase order creation and fulfillment, returns to vendors (RTV), and integration with inventory, accounting, and other modules through event-driven communication.

## Core Entities and Aggregates

### 1. Purchase Order Aggregate

**State Management:**

- Draft: Initial state, editable
- Submitted: Sent to vendor, awaiting confirmation
- Confirmed: Vendor has acknowledged
- Partially Received: Some items received
- Fully Received: All items received
- Cancelled: Order cancelled
- Closed: Order completed and archived

**Business Rules:**

- Purchase orders require valid vendor selection
- Items must have positive quantities and valid pricing
- Currency and exchange rates must be set for international orders
- Approval workflows based on order value thresholds
- Cannot modify confirmed orders without creating change orders
- Automatic status updates based on receipt completion

### 2. Vendor Aggregate

**State Management:**

- Active: Can receive purchase orders
- Suspended: Temporarily unable to transact
- Inactive: No longer available for new orders

**Business Rules:**

- Vendors must have valid payment terms configured
- Credit limits and outstanding balance tracking
- Performance metrics tracking (on-time delivery, quality ratings)
- Preferred vendor status for specific item categories
- Tax identification and compliance validation

### 3. RTV (Return to Vendor) Order Aggregate

**State Management:**

- Draft: Initial return request
- Authorized: Return approved internally
- Shipped: Items sent back to vendor
- Credited: Credit received from vendor
- Resolved: Return process completed
- Disputed: Issues with return processing

**Business Rules:**

- RTV orders must reference original purchase order
- Return authorization required before shipping
- Quality inspection documentation required
- Return shipping cost allocation rules
- Credit memo reconciliation requirements

## Commands and Events

### Purchase Order Commands

```elixir
# Creation and Modification
CreatePurchaseOrder
UpdatePurchaseOrderItems
SetPurchaseOrderTerms
ApplyPurchaseOrderDiscount

# Workflow
SubmitPurchaseOrder
ConfirmPurchaseOrder
ApprovePurchaseOrder
RejectPurchaseOrder
CancelPurchaseOrder

# Receiving
ReceivePurchaseOrderItems
RecordPartialReceipt
CompleteReceiving
ReportReceivingDiscrepancy

# Financial
AllocatePurchaseOrderCosts
RecordPrepayment
ProcessVendorInvoice
```

### Purchase Order Events

```elixir
PurchaseOrderCreated
PurchaseOrderItemsUpdated
PurchaseOrderSubmitted
PurchaseOrderConfirmed
PurchaseOrderApproved
PurchaseOrderRejected
PurchaseOrderCancelled

ItemsReceived
PartialReceiptRecorded
ReceivingCompleted
DiscrepancyReported

CostsAllocated
PrepaymentRecorded
VendorInvoiceProcessed
```

### Vendor Commands

```elixir
RegisterVendor
UpdateVendorInformation
SetVendorPaymentTerms
UpdateVendorCreditLimit
SuspendVendor
ReactivateVendor
DeactivateVendor
UpdateVendorPerformanceMetrics
```

### Vendor Events

```elixir
VendorRegistered
VendorInformationUpdated
VendorPaymentTermsSet
VendorCreditLimitUpdated
VendorSuspended
VendorReactivated
VendorDeactivated
VendorPerformanceUpdated
```

### RTV Commands

```elixir
InitiateReturn
AuthorizeReturn
ShipReturnItems
RecordReturnCredit
DisputeReturn
ResolveReturnDispute
CancelReturn
```

### RTV Events

```elixir
ReturnInitiated
ReturnAuthorized
ReturnItemsShipped
ReturnCreditRecorded
ReturnDisputed
ReturnDisputeResolved
ReturnCancelled
```

## Process Managers and Sagas

### Purchase Order Fulfillment Saga

**Responsibilities:**

- Coordinate order submission to vendor
- Track confirmation and acknowledgment
- Monitor delivery schedules
- Coordinate with inventory for receiving
- Update accounting with accruals
- Handle exceptions and escalations

**Key Interactions:**

- Inventory Module: Reserve storage space, update stock levels
- Accounting Module: Record liabilities, process payments
- Warehouse Module: Schedule receiving, quality inspection

### Three-Way Match Process

**Responsibilities:**

- Match purchase order with receiving documents
- Validate vendor invoice against order and receipt
- Identify and flag discrepancies
- Approve for payment or escalate issues

**Business Rules:**

- Tolerance levels for quantity and price variances
- Automatic approval for matches within tolerance
- Escalation workflows for significant discrepancies
- Hold payment until discrepancies resolved

### Return Authorization Process

**Responsibilities:**

- Validate return eligibility
- Coordinate quality inspection
- Generate return shipping documentation
- Track return shipment
- Reconcile credit memos
- Update inventory and accounting

**Key Interactions:**

- Quality Module: Inspection and documentation
- Shipping Module: Return logistics
- Accounting Module: Credit processing

## Integration Points

### Inventory Module Integration

**Outbound Events:**

- PurchaseOrderItemsReceived
- StockLevelsUpdateRequested
- ReturnItemsShipped

**Inbound Events Handled:**

- LowStockAlert
- ReorderPointReached
- StorageCapacityAvailable

**Business Logic:**

- Automatic purchase order generation for reorder points
- Update available-to-promise quantities
- Coordinate cycle counting after receipt

### Accounting Module Integration

**Outbound Events:**

- PurchaseOrderCommitted
- GoodsReceived
- VendorInvoiceApproved
- ReturnCreditReceived

**Inbound Events Handled:**

- PaymentProcessed
- BudgetExceeded
- AccountingPeriodClosed

**Business Logic:**

- Accrue liabilities upon order confirmation
- Record inventory value changes
- Process cost allocations and variances
- Update vendor account balances

### Sales Module Integration

**Outbound Events:**

- VendorLeadTimeUpdated
- ItemAvailabilityChanged
- DirectShipmentArranged

**Inbound Events Handled:**

- CustomerOrderRequiringPurchase
- DropShipmentRequested

**Business Logic:**

- Generate purchase orders for customer-specific items
- Coordinate drop shipments from vendors
- Update sales order availability based on purchase schedules

## Business Rules Engine

### Approval Workflows

```elixir
# Dynamic approval routing based on:
- Order value thresholds
- Item categories
- Vendor classifications
- Budget availability
- Department or project codes
```

### Vendor Selection Rules

```elixir
# Automated vendor selection based on:
- Preferred vendor agreements
- Best price within lead time requirements
- Quality ratings and performance history
- Geographic proximity for shipping efficiency
- Contract compliance requirements
```

### Cost Allocation Rules

```elixir
# Distribute costs based on:
- Direct item costs
- Freight and handling charges
- Import duties and taxes
- Quality inspection fees
- Insurance and other ancillary costs
```

## Compliance and Audit

### Audit Trail Requirements

- All state changes logged with timestamp and user
- Approval chains documented
- Price variance justifications recorded
- Return reasons and quality issues tracked
- Payment authorization history maintained

### Regulatory Compliance

- Tax calculation and reporting
- Import/export documentation
- Vendor compliance verification
- Conflict of interest checks
- Segregation of duties enforcement

## Performance Optimization

### Caching Strategies

- Vendor catalog and pricing information
- Frequently accessed purchase order templates
- Approval workflow configurations
- Tax rates and shipping tables

### Batch Processing

- Bulk purchase order generation
- Mass receiving operations
- Periodic vendor performance calculations
- Automated reorder processing

## Error Handling and Recovery

### Compensation Logic

- Reverse receiving entries for cancelled orders
- Void uncommitted purchase orders
- Adjust inventory for return processing
- Reconcile partial shipments

### Idempotency Requirements

- Purchase order number generation
- Receiving transaction processing
- Payment application
- Credit memo reconciliation

## Reporting and Analytics

### Key Metrics

- Purchase order cycle time
- Vendor performance scorecards
- Price variance analysis
- Return rate by vendor/item
- Budget vs. actual spending
- Lead time accuracy

### Real-time Dashboards

- Open purchase orders by status
- Receiving schedule
- Pending approvals
- Vendor payment status
- Return authorization queue

## Security and Access Control

### Role-Based Permissions

```elixir
# Buyer Role
- Create and modify purchase orders
- Select vendors
- Negotiate terms

# Approver Role
- Review and approve orders
- Override budget constraints
- Authorize returns

# Receiver Role
- Record goods receipt
- Report discrepancies
- Initiate quality holds

# Accountant Role
- Process invoices
- Approve payments
- Record adjustments
```

### Data Protection

- Vendor banking information encryption
- Purchase order history retention
- Sensitive pricing data access control
- Audit log tamper protection

## Extensibility Points

### Custom Fields

- Purchase order header extensions
- Line item attributes
- Vendor-specific data
- Project or department codes

### Workflow Customization

- Configurable approval chains
- Custom validation rules
- Industry-specific compliance checks
- Integration with external procurement systems

### Event Subscriptions

- Allow external modules to subscribe to purchase events
- Webhook notifications for vendor portal
- EDI message generation
- Custom reporting triggers

## Failure Scenarios and Recovery

### Network Failures

- Queue commands for retry
- Store events locally until connection restored
- Provide offline viewing of cached data
- Synchronize upon reconnection

### Module Unavailability

- Graceful degradation when inventory module offline
- Queue accounting updates for later processing
- Cache critical vendor data locally
- Provide manual override capabilities

### Data Consistency

- Event replay for aggregate reconstruction
- Snapshot management for performance
- Conflict resolution for concurrent updates
- Saga compensation for failed workflows
