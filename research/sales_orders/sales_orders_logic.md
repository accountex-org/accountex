# Sales Order Business Logic Document - Accountex System

## 1. Domain Overview

The Sales Order module in Accountex manages the complete lifecycle of customer orders from initial quote creation through fulfillment and invoicing. Built on an event-sourced architecture using Ash/AshCommanded framework, the system provides comprehensive order management capabilities with real-time integration across inventory, accounting, warehousing, and customer relationship modules.

## 2. Domain Concepts

### 2.1 Core Entities

#### Order
Primary aggregate representing a customer purchase request containing header information, line items, pricing, addresses, and fulfillment instructions.

```elixir
defmodule Accountex.Sales.Order do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]

  attributes do
    uuid_primary_key :id
    attribute :order_number, :string, allow_nil?: false
    attribute :customer_id, :uuid, allow_nil?: false
    attribute :order_type, :atom, 
      constraints: [one_of: [:standard, :blanket, :recurring, :drop_ship]]
    attribute :status, :atom,
      constraints: [one_of: [:draft, :pending, :approved, :pick_released, 
                            :shipped, :invoiced, :closed, :cancelled]]
    attribute :currency_code, :string, default: "USD"
    attribute :exchange_rate, :decimal, default: 1.0
    attribute :payment_terms, :string
    attribute :ship_to_address, :map
    attribute :bill_to_address, :map
    attribute :requested_ship_date, :date
    attribute :total_amount, :decimal
    attribute :tax_amount, :decimal
    attribute :discount_amount, :decimal
    attribute :credit_status, :atom
    create_timestamp :created_at
    update_timestamp :updated_at
  end
end
```

#### Order Line Item
Individual products or services within an order including quantity, pricing, and fulfillment details.

```elixir
defmodule Accountex.Sales.OrderLine do
  attributes do
    attribute :line_number, :integer
    attribute :item_id, :uuid
    attribute :item_type, :atom, constraints: [one_of: [:standard, :kit, :configurable]]
    attribute :quantity_ordered, :decimal
    attribute :quantity_shipped, :decimal, default: 0
    attribute :quantity_invoiced, :decimal, default: 0
    attribute :unit_price, :decimal
    attribute :discount_percent, :decimal
    attribute :tax_rate, :decimal
    attribute :line_total, :decimal
    attribute :allocation_status, :atom
    attribute :warehouse_id, :uuid
  end
end
```

#### Quote
Pre-order document with proposed pricing and terms requiring customer acceptance.

#### Customer
External aggregate referenced by orders containing credit limits, payment terms, and order history.

#### Inventory Item
Products available for sale with multi-location stock levels, pricing rules, and kit components.

### 2.2 Value Objects

- **Address**: Ship-to and bill-to location details
- **PricingDetails**: Complex pricing calculations including discounts and surcharges
- **TaxCalculation**: Geographic and product-based tax determination
- **CreditCheck**: Customer creditworthiness evaluation
- **AllocationResult**: Inventory reservation outcome

## 3. Business Workflows

### 3.1 Order Creation Workflow

**Process Flow:**
1. Customer and credit validation
2. Order header creation with automatic numbering
3. Line item entry with real-time pricing
4. Inventory availability checking (ATP)
5. Tax calculation based on ship-to location
6. Credit limit verification
7. Order submission for approval

**Business Rules:**
- Orders require valid customer with active status
- Credit check must pass based on order value and customer limit
- All line items must have positive quantities
- Pricing date determines applicable price lists
- Ship-to address required for physical items

### 3.2 Quote-to-Order Conversion

**Process Flow:**
1. Quote validation and expiration check
2. Customer acceptance recording
3. Price lock option to maintain quoted prices
4. Automatic order generation with quote reference
5. Optional partial conversion of quote lines
6. Quote status update to "Ordered"

**Business Rules:**
- Only approved quotes can convert to orders
- Expired quotes require re-approval
- Price changes trigger notification if variance exceeds threshold
- Quoted discounts transfer to order

### 3.3 Order Approval Process

**Multi-Level Approval Matrix:**

| Order Value | Customer Type | Required Approval |
|------------|--------------|------------------|
| < $10,000 | Standard | Automatic |
| $10,000 - $50,000 | Standard | Sales Manager |
| > $50,000 | Standard | Sales Director |
| Any | New Customer | Credit Manager |
| Any | Credit Hold | Finance Director |

**Approval Workflow:**
```elixir
defmodule Accountex.Sales.Workflows.OrderApproval do
  use Ash.Flow

  flow do
    argument :order_id, :uuid

    step :load_order do
      run fn %{order_id: order_id} ->
        Accountex.Sales.get_order!(order_id)
      end
    end

    branch :check_approval_required do
      condition fn %{order: order} ->
        order.total_amount > approval_threshold(order.customer)
      end

      if_true do
        step :route_to_approver
        step :await_approval
      end
    end

    step :update_status do
      run Accountex.Sales.Order.approve()
    end
  end
end
```

### 3.4 Inventory Allocation Process

**ATP Calculation Formula:**
```
ATP = On_Hand_Quantity 
    + Scheduled_Receipts 
    - Customer_Orders_Due
    - Safety_Stock
```

**Allocation Strategy:**
1. Check primary warehouse availability
2. Search alternate locations if needed
3. Create soft reservation during order entry
4. Convert to hard allocation upon approval
5. Handle backorders for unavailable items

**Kit Item Explosion:**
```elixir
def explode_kit_components(kit_item, quantity) do
  kit_item.components
  |> Enum.map(fn component ->
    %{
      item_id: component.item_id,
      required_qty: component.qty_per * quantity * (1 + component.scrap_factor),
      warehouse_id: determine_source_warehouse(component)
    }
  end)
  |> check_component_availability()
  |> reserve_components()
end
```

### 3.5 Pricing and Discount Calculation

**Price Determination Hierarchy:**
1. Customer + Product specific price
2. Customer price group + Product
3. Product category pricing
4. Standard list price

**Discount Calculation:**
```elixir
def calculate_line_discount(line_item, customer) do
  base_price = get_list_price(line_item.item_id, line_item.quantity)
  
  # Cascade multiple discounts
  standard_discount = get_standard_discount(customer.discount_group)
  volume_discount = calculate_volume_discount(line_item.quantity)
  promo_discount = get_promotional_discount(line_item.item_id)
  
  effective_discount = 1 - ((1 - standard_discount) * 
                           (1 - volume_discount) * 
                           (1 - promo_discount))
  
  final_price = base_price * (1 - effective_discount)
  
  %{
    base_price: base_price,
    discount_percent: effective_discount * 100,
    final_price: final_price
  }
end
```

### 3.6 Credit Management

**Credit Check Process:**
```elixir
def perform_credit_check(order, customer) do
  current_exposure = calculate_current_exposure(customer)
  available_credit = customer.credit_limit - current_exposure
  
  cond do
    customer.credit_status == :hold ->
      {:error, :customer_on_credit_hold}
    
    order.total_amount > available_credit ->
      {:hold, :credit_limit_exceeded}
    
    days_past_due(customer) > 60 ->
      {:hold, :past_due_invoices}
    
    true ->
      {:ok, :credit_approved}
  end
end
```

### 3.7 Order Fulfillment

**Pick-Pack-Ship Process:**
1. Release approved orders to warehouse
2. Generate pick lists by zone/wave
3. Confirm picked quantities
4. Pack with optimal cartonization
5. Calculate shipping rates
6. Generate labels and documentation
7. Update order status to shipped

**Partial Shipment Handling:**
```elixir
def process_partial_shipment(order, available_items) do
  shipped_lines = available_items
  backorder_lines = order.lines -- available_items
  
  # Create shipment for available items
  shipment = create_shipment(order, shipped_lines)
  
  # Split order for backorders
  if length(backorder_lines) > 0 do
    create_backorder(order, backorder_lines)
  end
  
  # Update original order status
  update_order_fulfillment_status(order)
end
```

### 3.8 Advanced Billing

**Milestone Billing Configuration:**
```elixir
defmodule Accountex.Sales.MilestoneBilling do
  def configure_milestones(order) do
    [
      %{milestone: "Contract Signing", percentage: 25, trigger: :manual},
      %{milestone: "Design Approval", percentage: 25, trigger: :manual},
      %{milestone: "50% Completion", percentage: 25, trigger: :automatic},
      %{milestone: "Final Delivery", percentage: 25, trigger: :ship_confirm}
    ]
  end
  
  def process_milestone_completion(order, milestone_name) do
    milestone = get_milestone(order, milestone_name)
    amount = order.total_amount * (milestone.percentage / 100)
    
    create_invoice(order, amount, milestone_name)
    recognize_revenue(order, amount)
  end
end
```

### 3.9 Blanket and Recurring Orders

**Blanket Order Management:**
```elixir
defmodule Accountex.Sales.BlanketOrder do
  attributes do
    attribute :agreement_number, :string
    attribute :customer_id, :uuid
    attribute :start_date, :date
    attribute :end_date, :date
    attribute :total_quantity, :decimal
    attribute :total_amount, :decimal
    attribute :released_quantity, :decimal, default: 0
    attribute :released_amount, :decimal, default: 0
    attribute :minimum_release_qty, :decimal
    attribute :pricing_terms, :map
  end
  
  def create_release(blanket_order, release_qty) do
    if can_release?(blanket_order, release_qty) do
      order = generate_sales_order(blanket_order, release_qty)
      update_blanket_consumption(blanket_order, release_qty)
      {:ok, order}
    else
      {:error, :release_constraints_violated}
    end
  end
end
```

## 4. Domain Events

### 4.1 Order Lifecycle Events

```elixir
defmodule Accountex.Sales.Events do
  defmodule OrderCreated do
    @derive Jason.Encoder
    defstruct [:order_id, :customer_id, :order_number, :total_amount, 
               :created_by, :created_at]
  end
  
  defmodule OrderApproved do
    defstruct [:order_id, :approved_by, :approved_at, :approval_level]
  end
  
  defmodule InventoryAllocated do
    defstruct [:order_id, :line_items, :allocation_type, :warehouse_id]
  end
  
  defmodule OrderShipped do
    defstruct [:order_id, :shipment_number, :tracking_number, :carrier, 
               :shipped_items, :shipped_at]
  end
  
  defmodule OrderInvoiced do
    defstruct [:order_id, :invoice_number, :invoice_amount, :invoiced_at]
  end
  
  defmodule OrderCancelled do
    defstruct [:order_id, :cancellation_reason, :cancelled_by, :cancelled_at]
  end
end
```

### 4.2 Event Handlers

```elixir
defmodule Accountex.Sales.EventHandlers.OrderEventHandler do
  use Commanded.Event.Handler,
    application: Accountex.App,
    name: "OrderEventHandler"

  def handle(%OrderCreated{} = event) do
    # Update read model
    create_order_projection(event)
    
    # Trigger credit check
    dispatch_command(%CheckCustomerCredit{
      customer_id: event.customer_id,
      order_amount: event.total_amount
    })
  end
  
  def handle(%OrderApproved{} = event) do
    # Initiate fulfillment process
    dispatch_command(%ReleaseOrderToWarehouse{
      order_id: event.order_id
    })
    
    # Reserve inventory
    dispatch_command(%ReserveInventory{
      order_id: event.order_id
    })
  end
end
```

## 5. Business Rules

### 5.1 Order Entry Rules
- Minimum order value enforcement by customer type
- Maximum line items per order (configurable)
- Required fields validation based on order type
- Date validation for requested ship dates
- Currency restrictions by customer region

### 5.2 Pricing Rules
- Price list effectivity date validation
- Quantity break application
- Discount stacking limitations
- Manual price override authorization levels
- Price variance tolerance thresholds

### 5.3 Inventory Rules
- Safety stock maintenance
- Allocation priority by customer class
- Kit component availability requirements
- Substitution approval requirements
- Backorder acceptance criteria

### 5.4 Credit Rules
- Credit limit enforcement
- Payment term restrictions
- Hold release authority levels
- Aging threshold policies
- Credit insurance requirements

### 5.5 Fulfillment Rules
- Partial shipment minimum thresholds
- Carrier selection by service level
- Hazmat shipping restrictions
- International trade compliance
- Drop ship vendor requirements

## 6. Commands and Queries

### 6.1 Commands

```elixir
defmodule Accountex.Sales.Commands do
  defmodule CreateOrder do
    defstruct [:order_id, :customer_id, :order_type, :line_items, 
               :ship_to_address, :bill_to_address]
    
    use Vex.Struct
    validates :customer_id, presence: true
    validates :line_items, length: [min: 1]
  end
  
  defmodule ApproveOrder do
    defstruct [:order_id, :approver_id, :approval_notes]
  end
  
  defmodule AllocateInventory do
    defstruct [:order_id, :allocation_strategy]
  end
  
  defmodule ShipOrder do
    defstruct [:order_id, :shipment_details, :tracking_info]
  end
  
  defmodule CancelOrder do
    defstruct [:order_id, :reason, :cancelled_by]
  end
end
```

### 6.2 Queries

```elixir
defmodule Accountex.Sales.Queries do
  def get_order_status(order_id) do
    Repo.get!(OrderProjection, order_id).status
  end
  
  def calculate_order_availability(order_id) do
    order = get_order_with_lines(order_id)
    
    order.lines
    |> Enum.map(&check_item_availability/1)
    |> aggregate_availability_results()
  end
  
  def get_customer_order_history(customer_id, date_range) do
    from(o in OrderProjection,
      where: o.customer_id == ^customer_id,
      where: o.created_at >= ^date_range.start,
      where: o.created_at <= ^date_range.end,
      order_by: [desc: o.created_at]
    )
    |> Repo.all()
  end
end
```

## 7. Process Managers (Sagas)

### 7.1 Order Fulfillment Saga

```elixir
defmodule Accountex.Sales.Sagas.OrderFulfillmentSaga do
  use Commanded.ProcessManagers.ProcessManager,
    application: Accountex.App,
    name: "OrderFulfillmentSaga"

  defstruct [:order_id, :customer_id, :payment_status, :inventory_status, 
             :shipping_status, :invoice_status]

  # Saga orchestration
  def interested?(%OrderApproved{order_id: id}), do: {:start, id}
  def interested?(%PaymentReceived{order_id: id}), do: {:continue, id}
  def interested?(%InventoryAllocated{order_id: id}), do: {:continue, id}
  def interested?(%OrderShipped{order_id: id}), do: {:continue, id}
  def interested?(%OrderInvoiced{order_id: id}), do: {:stop, id}
  
  def handle(%{order_id: order_id}, %OrderApproved{}) do
    [
      %AllocateInventory{order_id: order_id},
      %ProcessPayment{order_id: order_id}
    ]
  end
  
  def handle(%{payment_status: :completed, inventory_status: :allocated} = state, _) do
    %ReleaseOrderForShipping{order_id: state.order_id}
  end
  
  def handle(state, %OrderShipped{}) do
    %GenerateInvoice{order_id: state.order_id}
  end
  
  # Compensation logic
  def error({:error, :insufficient_inventory}, %AllocateInventory{}, state) do
    %NotifyBackorder{order_id: state.order_id}
  end
end
```

## 8. Integration Points

### 8.1 Accounts Receivable Integration
- Real-time credit limit checking
- Automatic invoice posting
- Payment application
- Aging analysis updates
- Collection hold management

### 8.2 Inventory Management Integration
- ATP calculations
- Multi-warehouse visibility
- Lot/serial tracking
- Cycle count adjustments
- Transfer order creation

### 8.3 General Ledger Integration
- Revenue recognition
- COGS posting
- Tax liability recording
- Deferred revenue management
- Journal entry creation

### 8.4 CRM Integration
- Customer profile synchronization
- Opportunity conversion
- Activity logging
- Campaign response tracking
- Lead qualification

### 8.5 Warehouse Management Integration
- Pick list generation
- Wave planning
- Cartonization
- Shipping documentation
- Returns processing

## 9. Read Models and Projections

```elixir
defmodule Accountex.Sales.Projections.OrderProjection do
  use Ecto.Schema

  schema "order_projections" do
    field :order_number, :string
    field :customer_id, Ecto.UUID
    field :customer_name, :string
    field :status, :string
    field :total_amount, :decimal
    field :open_amount, :decimal
    field :shipped_amount, :decimal
    field :invoiced_amount, :decimal
    field :created_at, :utc_datetime
    field :updated_at, :utc_datetime
  end
end

defmodule Accountex.Sales.Projections.OrderAnalytics do
  use Ecto.Schema
  
  schema "order_analytics" do
    field :date, :date
    field :order_count, :integer
    field :total_revenue, :decimal
    field :average_order_value, :decimal
    field :fulfillment_rate, :decimal
    field :cancellation_rate, :decimal
  end
end
```

## 10. Security and Compliance

### 10.1 Authorization Policies
```elixir
defmodule Accountex.Sales.Policies do
  use Ash.Policy.Authorizer

  policies do
    policy action(:create_order) do
      authorize_if relates_to_actor_via(:sales_rep_id)
      authorize_if has_permission(:order_create)
    end
    
    policy action(:approve_order) do
      authorize_if expr(total_amount <= ^actor(:approval_limit))
      forbid_if expr(status != :pending)
    end
    
    policy action(:cancel_order) do
      authorize_if has_permission(:order_cancel)
      forbid_if expr(status in [:shipped, :invoiced])
    end
  end
end
```

### 10.2 Audit Requirements
- All order modifications logged with user and timestamp
- Price override justifications required
- Credit limit override tracking
- Cancellation reason codes mandatory
- Document version history maintained

## 11. Performance Optimizations

### 11.1 Caching Strategies
- Customer data caching with TTL
- Price list caching by effective date
- Inventory availability caching with invalidation
- Tax rate caching by jurisdiction
- Credit limit caching with real-time updates

### 11.2 Event Store Optimization
- Snapshot creation every 100 events
- Event archival after 90 days
- Projection rebuild capabilities
- Event replay performance tuning
- Read model denormalization

## 12. Error Handling and Recovery

### 12.1 Compensation Strategies
```elixir
def compensate_failed_allocation(order_id) do
  with {:ok, order} <- get_order(order_id),
       {:ok, _} <- release_soft_reservations(order),
       {:ok, _} <- notify_customer_of_delay(order),
       {:ok, _} <- create_backorder_if_needed(order) do
    {:ok, :compensated}
  else
    error -> 
      Logger.error("Compensation failed: #{inspect(error)}")
      escalate_to_manual_intervention(order_id)
  end
end
```

### 12.2 Retry Policies
- Transient failure retry with exponential backoff
- Maximum retry attempts configurable by operation
- Dead letter queue for failed operations
- Manual intervention workflows
- Automated escalation procedures

## 13. Monitoring and Analytics

### 13.1 Key Performance Indicators
- Order cycle time
- Fulfillment accuracy rate
- Order value trends
- Cancellation reasons analysis
- Credit hold impact metrics

### 13.2 Event Stream Analytics
- Real-time order velocity monitoring
- Inventory allocation success rates
- Payment processing metrics
- System performance monitoring
- Business event correlation

This comprehensive business logic document provides the foundation for implementing a robust, scalable Sales Order management system within the Accountex platform using event-sourced architecture and modern integration patterns.
