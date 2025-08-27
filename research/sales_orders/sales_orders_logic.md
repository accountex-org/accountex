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

**BR-SO-001:** Orders require valid customer with active status
**BR-SO-002:** Credit check must pass based on order value and customer limit
**BR-SO-003:** All line items must have positive quantities
**BR-SO-004:** Pricing date determines applicable price lists
**BR-SO-005:** Ship-to address required for physical items

### 3.2 Quote-to-Order Conversion

**Process Flow:**

1. Quote validation and expiration check
2. Customer acceptance recording
3. Price lock option to maintain quoted prices
4. Automatic order generation with quote reference
5. Optional partial conversion of quote lines
6. Quote status update to "Ordered"

**Business Rules:**

**BR-SO-006:** Only approved quotes can convert to orders
**BR-SO-007:** Expired quotes require re-approval
**BR-SO-008:** Price changes trigger notification if variance exceeds threshold
**BR-SO-009:** Quoted discounts transfer to order

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

**BR-SO-010:** Minimum order value enforcement by customer type
**BR-SO-011:** Maximum line items per order (configurable)
**BR-SO-012:** Required fields validation based on order type
**BR-SO-013:** Date validation for requested ship dates
**BR-SO-014:** Currency restrictions by customer region

### 5.2 Pricing Rules

**BR-SO-015:** Price list effectivity date validation
**BR-SO-016:** Quantity break application
**BR-SO-017:** Discount stacking limitations
**BR-SO-018:** Manual price override authorization levels
**BR-SO-019:** Price variance tolerance thresholds

### 5.3 Inventory Rules

**BR-SO-020:** Safety stock maintenance
**BR-SO-021:** Allocation priority by customer class
**BR-SO-022:** Kit component availability requirements
**BR-SO-023:** Substitution approval requirements
**BR-SO-024:** Backorder acceptance criteria

### 5.4 Credit Rules

**BR-SO-025:** Credit limit enforcement
**BR-SO-026:** Payment term restrictions
**BR-SO-027:** Hold release authority levels
**BR-SO-028:** Aging threshold policies
**BR-SO-029:** Credit insurance requirements

### 5.5 Fulfillment Rules

**BR-SO-030:** Partial shipment minimum thresholds
**BR-SO-031:** Carrier selection by service level
**BR-SO-032:** Hazmat shipping restrictions
**BR-SO-033:** International trade compliance
**BR-SO-034:** Drop ship vendor requirements

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

**BR-SO-035:** All order modifications logged with user and timestamp
**BR-SO-036:** Price override justifications required
**BR-SO-037:** Credit limit override tracking
**BR-SO-038:** Cancellation reason codes mandatory
**BR-SO-039:** Document version history maintained

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

# Accountex Sales Order System - Business Logic Document (Part 2)

## 4. Shipping sales orders process

### Commands

```elixir
# Ship order command with validation
defmodule Accountex.Sales.Commands.ShipOrder do
  defstruct [
    :order_id,
    :warehouse_id,
    :shipment_items,
    :carrier,
    :tracking_number,
    :shipping_method,
    :actual_ship_date,
    :picker_id,
    :packer_id,
    :override_validations
  ]

  @type shipment_item :: %{
    line_item_id: String.t(),
    quantity_shipped: integer(),
    serial_numbers: list(String.t()),
    lot_numbers: list(String.t()),
    bin_locations: list(String.t())
  }

  # Validation rules
  def validate(command) do
    with :ok <- validate_order_status(command),
         :ok <- validate_inventory_allocation(command),
         :ok <- validate_shipping_quantities(command),
         :ok <- validate_special_items(command),
         :ok <- validate_carrier_integration(command) do
      :ok
    end
  end
end

# Partial shipment command
defmodule Accountex.Sales.Commands.CreatePartialShipment do
  defstruct [
    :order_id,
    :shipment_reason,
    :selected_items,
    :warehouse_id,
    :expected_remaining_shipments,
    :customer_notified
  ]
end

# Handle over-shipment command
defmodule Accountex.Sales.Commands.HandleOverShipment do
  defstruct [
    :order_id,
    :item_id,
    :excess_quantity,
    :resolution_type, # :customer_keeps | :return_to_warehouse | :credit_customer
    :manager_approval_id
  ]
end
```

### Events

```elixir
defmodule Accountex.Sales.Events.OrderShipped do
  defstruct [
    :order_id,
    :shipment_id,
    :warehouse_id,
    :shipped_items,
    :tracking_number,
    :carrier,
    :ship_date,
    :expected_delivery,
    :shipping_cost
  ]
end

defmodule Accountex.Sales.Events.PartialShipmentCreated do
  defstruct [
    :order_id,
    :shipment_id,
    :shipped_items,
    :remaining_items,
    :shipment_number,
    :total_shipments_expected
  ]
end

defmodule Accountex.Sales.Events.InventoryAllocated do
  defstruct [
    :order_id,
    :allocations,
    :warehouse_id,
    :allocation_timestamp,
    :reservation_expiry
  ]
end

defmodule Accountex.Sales.Events.PackingSlipGenerated do
  defstruct [
    :order_id,
    :shipment_id,
    :document_url,
    :items,
    :special_instructions
  ]
end

defmodule Accountex.Sales.Events.InvoiceAutomaticallyGenerated do
  defstruct [
    :order_id,
    :invoice_id,
    :shipment_id,
    :invoice_amount,
    :payment_terms,
    :due_date
  ]
end

defmodule Accountex.Sales.Events.OverShipmentDetected do
  defstruct [
    :order_id,
    :item_id,
    :ordered_quantity,
    :shipped_quantity,
    :excess_quantity,
    :detection_timestamp
  ]
end
```

### Aggregates

```elixir
defmodule Accountex.Sales.Aggregates.ShipmentAggregate do
  defstruct [
    :shipment_id,
    :order_id,
    :status, # :pending | :picking | :packing | :shipped | :delivered
    :warehouse_id,
    :shipment_lines,
    :tracking_info,
    :documents,
    :actual_vs_planned_quantities,
    :special_handling_flags
  ]

  def execute(%__MODULE__{status: :pending} = shipment, %AllocateInventory{} = cmd) do
    # State transition: pending → picking
    events = [
      %InventoryAllocated{
        allocations: calculate_allocations(cmd),
        warehouse_id: cmd.warehouse_id
      },
      %PickingStarted{
        pick_list: generate_pick_list(shipment, cmd),
        picker_id: cmd.picker_id
      }
    ]
    {shipment |> Map.put(:status, :picking), events}
  end

  def execute(%__MODULE__{status: :picking} = shipment, %CompletePicking{} = cmd) do
    # Handle discrepancies and transition to packing
    discrepancies = detect_pick_discrepancies(shipment, cmd)
    
    events = case discrepancies do
      [] -> 
        [%PickingCompleted{items_picked: cmd.items}]
      _ ->
        [%PickingCompleted{items_picked: cmd.items},
         %DiscrepanciesDetected{discrepancies: discrepancies}]
    end
    
    {shipment |> Map.put(:status, :packing), events}
  end

  def execute(%__MODULE__{status: :packing} = shipment, %ConfirmShipment{} = cmd) do
    # Final validation and shipment confirmation
    with :ok <- validate_packed_quantities(shipment, cmd),
         :ok <- validate_shipping_documents(cmd) do
      
      events = [
        %OrderShipped{
          shipment_id: shipment.shipment_id,
          tracking_number: cmd.tracking_number
        },
        %InventoryDeducted{
          items: shipment.shipment_lines,
          warehouse_id: shipment.warehouse_id
        }
      ]
      
      # Check for over-shipments
      over_shipments = detect_over_shipments(shipment)
      events = if over_shipments != [] do
        events ++ Enum.map(over_shipments, &create_over_shipment_event/1)
      else
        events
      end
      
      {shipment |> Map.put(:status, :shipped), events}
    end
  end
end
```

### Read Models/Projections

```elixir
defmodule Accountex.Sales.Projections.ShipmentStatusProjection do
  use Commanded.Projections.Ecto, name: "shipment_status"

  schema "shipment_status" do
    field :order_id, :string
    field :shipment_id, :string
    field :status, :string
    field :tracking_number, :string
    field :carrier, :string
    field :shipped_quantity, :integer
    field :ordered_quantity, :integer
    field :ship_date, :date
    field :expected_delivery, :date
    field :warehouse_id, :string
    field :is_partial, :boolean
    field :shipment_number, :integer
    field :total_shipments, :integer
  end

  project %OrderShipped{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :shipment_status, %__MODULE__{
      order_id: event.order_id,
      shipment_id: event.shipment_id,
      status: "shipped",
      tracking_number: event.tracking_number,
      carrier: event.carrier,
      ship_date: event.ship_date,
      expected_delivery: event.expected_delivery
    })
  end
end

defmodule Accountex.Sales.Projections.InventoryMovementProjection do
  use Commanded.Projections.Ecto, name: "inventory_movements"

  schema "inventory_movements" do
    field :item_id, :string
    field :warehouse_id, :string
    field :movement_type, :string # :allocated | :picked | :shipped | :returned
    field :quantity, :integer
    field :order_id, :string
    field :timestamp, :utc_datetime
    field :available_quantity, :integer
    field :allocated_quantity, :integer
    field :in_transit_quantity, :integer
  end
end
```

### Process Managers/Sagas

```elixir
defmodule Accountex.Sales.ProcessManagers.ShippingProcessManager do
  use Commanded.ProcessManagers.ProcessManager,
    name: "shipping_process",
    consistency: :strong

  defstruct [
    :order_id,
    :shipment_ids,
    :warehouse_allocations,
    :partial_shipment_count,
    :invoice_generated,
    :customer_notifications_sent
  ]

  def interested?(%OrderConfirmed{order_id: order_id}), do: {:start, order_id}
  def interested?(%InventoryAllocated{order_id: order_id}), do: {:continue, order_id}
  def interested?(%OrderShipped{order_id: order_id}), do: {:continue, order_id}
  def interested?(%InvoiceGenerated{order_id: order_id}), do: {:continue, order_id}
  def interested?(%OrderFullyShipped{order_id: order_id}), do: {:stop, order_id}

  def handle(%__MODULE__{} = state, %OrderConfirmed{} = event) do
    # Start shipping workflow
    %DetermineOptimalWarehouse{
      order_id: event.order_id,
      items: event.items,
      shipping_address: event.shipping_address,
      requested_ship_date: event.requested_ship_date
    }
  end

  def handle(%__MODULE__{} = state, %InventoryAllocated{} = event) do
    # Generate picking instructions
    %InitiatePicking{
      order_id: event.order_id,
      warehouse_id: event.warehouse_id,
      allocated_items: event.allocations
    }
  end

  def handle(%__MODULE__{} = state, %OrderShipped{} = event) do
    commands = []
    
    # Generate invoice if payment terms require it
    commands = if should_generate_invoice?(state, event) do
      commands ++ [%GenerateInvoice{
        order_id: event.order_id,
        shipment_id: event.shipment_id,
        invoice_type: :shipment
      }]
    else
      commands
    end
    
    # Update inventory
    commands ++ [%UpdateInventoryLevels{
      warehouse_id: event.warehouse_id,
      deductions: event.shipped_items
    }]
  end
end

defmodule Accountex.Sales.ProcessManagers.PartialShipmentManager do
  use Commanded.ProcessManagers.ProcessManager,
    name: "partial_shipment_manager"

  def handle(%__MODULE__{} = state, %PartialShipmentRequired{} = event) do
    # Orchestrate multiple shipments
    [
      %CreatePartialShipment{
        order_id: event.order_id,
        selected_items: determine_first_shipment_items(event)
      },
      %NotifyCustomerOfPartialShipment{
        order_id: event.order_id,
        expected_shipments: calculate_total_shipments(event)
      },
      %ScheduleRemainingShipments{
        order_id: event.order_id,
        remaining_items: event.remaining_items
      }
    ]
  end
end
```

### Integration Points

```elixir
defmodule Accountex.Sales.Integrations.ShippingIntegrations do
  # Warehouse Management System
  def sync_with_wms(shipment) do
    %{
      endpoint: "/wms/shipments",
      method: :post,
      payload: %{
        order_id: shipment.order_id,
        pick_list: shipment.pick_list,
        priority: shipment.priority,
        special_handling: shipment.special_handling_codes
      }
    }
  end

  # Carrier integrations
  def integrate_with_carriers() do
    %{
      fedex: %{rate_shop: "/fedex/rates", label: "/fedex/label", tracking: "/fedex/track"},
      ups: %{rate_shop: "/ups/rates", label: "/ups/label", tracking: "/ups/track"},
      usps: %{rate_shop: "/usps/rates", label: "/usps/label", tracking: "/usps/track"}
    }
  end

  # Document generation
  def generate_shipping_documents(shipment) do
    %{
      packing_slip: generate_packing_slip(shipment),
      shipping_label: generate_shipping_label(shipment),
      commercial_invoice: if international?(shipment), do: generate_commercial_invoice(shipment),
      hazmat_declaration: if hazmat?(shipment), do: generate_hazmat_docs(shipment)
    }
  end
end
```

### Business Rules and Constraints

```elixir
defmodule Accountex.Sales.Rules.ShippingRules do
  def shipping_cutoff_times do
    %{
      same_day: ~T[14:00:00],
      next_day: ~T[17:00:00],
      standard: ~T[20:00:00]
    }
  end

  def validate_shipping_constraints(order, shipment) do
    rules = [
      # BR-SO-040: Cannot ship without payment authorization if required
      {:payment_authorized, order.payment_status in [:paid, :credit_approved]},
      
      # BR-SO-041: Cannot exceed customer credit limit
      {:credit_limit, order.total_amount <= customer.credit_limit - customer.current_exposure},
      
      # BR-SO-042: Must validate shipping address
      {:valid_address, validate_address(shipment.shipping_address)},
      
      # BR-SO-043: Cannot ship restricted items to certain locations
      {:restricted_items, !has_restricted_items?(order.items, shipment.destination)},
      
      # BR-SO-044: Special handling for hazmat
      {:hazmat_compliance, validate_hazmat_requirements(order.items)},
      
      # BR-SO-045: Serialized items must have serial numbers
      {:serial_tracking, all_serials_captured?(shipment.items)}
    ]
    
    apply_rules(rules)
  end

  def partial_shipment_rules do
    %{
      min_value_per_shipment: 50.00,
      max_shipments_per_order: 5,
      customer_preference_required: true,
      notification_required: true
    }
  end

  def over_shipment_thresholds do
    %{
      auto_approval_limit: 10, # percentage
      manager_approval_limit: 500.00, # dollar amount
      customer_notification_required: true,
      resolution_time_limit: 24 # hours
    }
  end
end
```

### Error Handling

```elixir
defmodule Accountex.Sales.Errors.ShippingErrors do
  defmodule InsufficientInventoryError do
    defexception [:message, :order_id, :item_id, :requested, :available]
  end

  defmodule CarrierIntegrationError do
    defexception [:message, :carrier, :operation, :retry_after]
  end

  defmodule ShippingValidationError do
    defexception [:message, :validation_errors, :order_id]
  end

  def handle_shipping_failure(error, context) do
    case error do
      %InsufficientInventoryError{} ->
        [
          %NotifyWarehouseManager{issue: error},
          %CreateBackorder{order_id: error.order_id, item_id: error.item_id},
          %NotifyCustomerOfDelay{order_id: error.order_id}
        ]
      
      %CarrierIntegrationError{retry_after: retry_time} ->
        %ScheduleRetry{
          operation: context.operation,
          retry_at: DateTime.add(DateTime.utc_now(), retry_time)
        }
      
      %ShippingValidationError{} ->
        %RequireManualIntervention{
          order_id: error.order_id,
          errors: error.validation_errors,
          assigned_to: :shipping_supervisor
        }
    end
  end
end
```

## 5. Canceling open orders process

### Commands

```elixir
defmodule Accountex.Sales.Commands.CancelOrder do
  defstruct [
    :order_id,
    :cancellation_reason_code,
    :cancellation_category, # :customer_initiated | :vendor_initiated | :system_process
    :detailed_explanation,
    :cancelled_by,
    :requires_approval
  ]

  def validate(command) do
    with :ok <- validate_order_cancellable(command),
         :ok <- validate_cancellation_timing(command),
         :ok <- validate_reason_code(command),
         :ok <- check_approval_requirements(command) do
      :ok
    end
  end
end

defmodule Accountex.Sales.Commands.BulkCancelOrders do
  defstruct [
    :order_ids,
    :filter_criteria, # Optional: alternative to explicit order_ids
    :cancellation_reason_code,
    :requested_by,
    :approval_id,
    :notify_customers
  ]
end

defmodule Accountex.Sales.Commands.ProcessCancellationRefund do
  defstruct [
    :order_id,
    :refund_amount,
    :restocking_fee,
    :tax_adjustments,
    :refund_method, # :original_payment | :store_credit | :check
    :approval_status
  ]
end
```

### Events

```elixir
defmodule Accountex.Sales.Events.OrderCanceled do
  defstruct [
    :order_id,
    :cancellation_reason_code,
    :cancellation_category,
    :detailed_explanation,
    :cancelled_by,
    :cancelled_at,
    :order_status_at_cancellation,
    :lost_revenue_amount
  ]
end

defmodule Accountex.Sales.Events.BulkCancellationCompleted do
  defstruct [
    :batch_id,
    :total_orders_canceled,
    :successful_cancellations,
    :failed_cancellations,
    :total_lost_revenue,
    :cancellation_reason_code
  ]
end

defmodule Accountex.Sales.Events.InventoryReleased do
  defstruct [
    :order_id,
    :released_items,
    :warehouse_id,
    :release_timestamp,
    :available_for_reallocation
  ]
end

defmodule Accountex.Sales.Events.CancellationRefundProcessed do
  defstruct [
    :order_id,
    :refund_amount,
    :restocking_fee_charged,
    :tax_refunded,
    :refund_method,
    :refund_transaction_id
  ]
end

defmodule Accountex.Sales.Events.LostSaleRecorded do
  defstruct [
    :order_id,
    :customer_id,
    :lost_revenue,
    :reason_category,
    :reason_code,
    :competitor_won, # Optional
    :recovery_opportunity
  ]
end
```

### Aggregates

```elixir
defmodule Accountex.Sales.Aggregates.OrderCancellationAggregate do
  defstruct [
    :order_id,
    :status,
    :cancellation_state, # :not_cancelled | :pending_approval | :approved | :cancelled
    :allocated_inventory,
    :fulfillment_status,
    :payments_received,
    :refunds_issued,
    :cancellation_audit_trail
  ]

  def execute(%__MODULE__{status: status} = order, %CancelOrder{} = cmd) 
      when status in [:open, :confirmed, :partially_shipped] do
    
    # Check if cancellation requires approval
    needs_approval = requires_cancellation_approval?(order, cmd)
    
    if needs_approval do
      {order |> Map.put(:cancellation_state, :pending_approval),
       [%CancellationApprovalRequested{
         order_id: cmd.order_id,
         reason: cmd.cancellation_reason_code,
         requested_by: cmd.cancelled_by
       }]}
    else
      execute_cancellation(order, cmd)
    end
  end

  defp execute_cancellation(order, cmd) do
    events = [
      %OrderCanceled{
        order_id: cmd.order_id,
        cancellation_reason_code: cmd.cancellation_reason_code,
        lost_revenue_amount: calculate_lost_revenue(order)
      },
      %InventoryReleased{
        order_id: cmd.order_id,
        released_items: order.allocated_inventory
      },
      %LostSaleRecorded{
        order_id: cmd.order_id,
        lost_revenue: order.total_amount,
        reason_code: cmd.cancellation_reason_code
      }
    ]
    
    # Add refund event if payment was received
    events = if order.payments_received > 0 do
      events ++ [%RefundInitiated{
        order_id: cmd.order_id,
        refund_amount: calculate_refund_amount(order, cmd)
      }]
    else
      events
    end
    
    {order |> Map.put(:status, :cancelled) |> Map.put(:cancellation_state, :cancelled), events}
  end

  defp requires_cancellation_approval?(order, cmd) do
    cond do
      order.total_amount > 5000 -> true
      order.status == :partially_shipped -> true
      order.customer.vip_status -> true
      in_fulfillment?(order) -> true
      true -> false
    end
  end
end
```

### Read Models/Projections

```elixir
defmodule Accountex.Sales.Projections.CancellationAnalyticsProjection do
  use Commanded.Projections.Ecto, name: "cancellation_analytics"

  schema "cancellation_analytics" do
    field :period, :string # "2024-01" format
    field :total_cancellations, :integer
    field :cancellation_rate, :decimal
    field :lost_revenue, :decimal
    field :reason_breakdown, :map
    field :customer_segment_breakdown, :map
    field :avg_time_to_cancel, :integer # hours
    field :recovery_rate, :decimal
  end

  project %OrderCanceled{} = event, _metadata, fn multi ->
    # Update analytics for the period
    period = Calendar.strftime(event.cancelled_at, "%Y-%m")
    
    multi
    |> Ecto.Multi.run(:analytics, fn repo, _changes ->
      update_cancellation_analytics(repo, period, event)
    end)
  end
end

defmodule Accountex.Sales.Projections.LostSalesProjection do
  use Commanded.Projections.Ecto, name: "lost_sales"

  schema "lost_sales_tracking" do
    field :order_id, :string
    field :customer_id, :string
    field :lost_revenue, :decimal
    field :reason_code, :string
    field :reason_category, :string
    field :cancellation_date, :date
    field :order_age_at_cancellation, :integer # days
    field :competitor_won, :string
    field :recovery_attempted, :boolean
    field :recovered, :boolean
  end
end
```

### Process Managers/Sagas

```elixir
defmodule Accountex.Sales.ProcessManagers.CancellationProcessManager do
  use Commanded.ProcessManagers.ProcessManager,
    name: "cancellation_process"

  defstruct [
    :order_id,
    :cancellation_stage,
    :inventory_released,
    :refund_processed,
    :customer_notified,
    :fulfillment_stopped
  ]

  def handle(%__MODULE__{} = state, %OrderCanceled{} = event) do
    commands = []
    
    # Stop fulfillment if in progress
    commands = if in_fulfillment?(event.order_status_at_cancellation) do
      commands ++ [%StopFulfillment{order_id: event.order_id}]
    else
      commands
    end
    
    # Release inventory
    commands = commands ++ [%ReleaseOrderInventory{order_id: event.order_id}]
    
    # Process refund if needed
    commands = if event.payments_received > 0 do
      commands ++ [%ProcessCancellationRefund{
        order_id: event.order_id,
        refund_amount: calculate_refund(event)
      }]
    else
      commands
    end
    
    # Notify customer
    commands ++ [%SendCancellationNotification{
      order_id: event.order_id,
      customer_id: event.customer_id,
      reason: event.cancellation_reason_code
    }]
  end
end

defmodule Accountex.Sales.ProcessManagers.BulkCancellationManager do
  use Commanded.ProcessManagers.ProcessManager,
    name: "bulk_cancellation"

  def handle(%__MODULE__{} = state, %BulkCancellationRequested{} = event) do
    # Process orders in batches
    event.order_ids
    |> Enum.chunk_every(50)
    |> Enum.map(fn batch ->
      %ProcessCancellationBatch{
        batch_id: UUID.generate(),
        order_ids: batch,
        reason_code: event.cancellation_reason_code
      }
    end)
  end
end
```

### Business Rules and Constraints

```elixir
defmodule Accountex.Sales.Rules.CancellationRules do
  def cancellation_reason_codes do
    %{
      customer_initiated: [
        "CR01", # Changed mind
        "CR02", # Found better price
        "CR03", # Delivery too slow
        "CR04", # Budget constraints
        "CR05"  # Order mistake
      ],
      vendor_initiated: [
        "IN01", # Product discontinued
        "IN02", # Stock shortage
        "IN03", # Quality defect
        "IN04", # Seasonal unavailable
        "IN05"  # Supplier delay
      ],
      system_process: [
        "PE01", # Duplicate order
        "PE02", # Pricing error
        "PE03", # System malfunction
        "PE04", # Data entry error
        "PE05"  # Wrong customer
      ],
      credit_payment: [
        "CP01", # Credit limit exceeded
        "CP02", # Payment declined
        "CP03", # Fraud suspected
        "CP04", # Collection issues
        "CP05"  # Currency restrictions
      ]
    }
  end

  def cancellation_cutoff_rules do
    %{
      same_day_cutoff: ~T[14:00:00], # BR-SO-046
      in_fulfillment_requires_approval: true, # BR-SO-047
      shipped_orders_not_cancellable: true, # BR-SO-048
      max_days_after_order: 30 # BR-SO-049
    }
  end

  def refund_rules do
    %{
      full_refund_period: 24, # hours BR-SO-050
      restocking_fee_percentage: 15, # BR-SO-051
      restocking_fee_max: 500.00, # BR-SO-052
      tax_refund_required: true, # BR-SO-053
      original_payment_method_required: true # BR-SO-054
    }
  end

  def approval_thresholds do
    %{
      value_threshold: 5000.00, # BR-SO-055
      vip_customer_approval: true, # BR-SO-056
      partially_shipped_approval: true, # BR-SO-057
      bulk_cancellation_threshold: 10 # orders BR-SO-058
    }
  end
end
```

## 6. Approving sales quotes process

### Commands

```elixir
defmodule Accountex.Sales.Commands.ApproveQuote do
  defstruct [
    :quote_id,
    :approved_by,
    :approval_level,
    :approval_notes,
    :conditions_attached,
    :credit_check_override
  ]

  def validate(command) do
    with :ok <- validate_quote_active(command),
         :ok <- validate_approval_authority(command),
         :ok <- validate_quote_expiration(command),
         :ok <- validate_pricing_current(command) do
      :ok
    end
  end
end

defmodule Accountex.Sales.Commands.ConvertQuoteToOrder do
  defstruct [
    :quote_id,
    :selected_line_items, # nil means all items
    :order_split_criteria,
    :requested_delivery_date,
    :po_number,
    :special_instructions
  ]
end

defmodule Accountex.Sales.Commands.PerformCreditCheck do
  defstruct [
    :customer_id,
    :quote_id,
    :requested_credit_amount,
    :check_type, # :soft | :hard
    :include_existing_exposure
  ]
end

defmodule Accountex.Sales.Commands.HandleOverbooking do
  defstruct [
    :quote_id,
    :overbooking_strategy, # :backorder | :partial | :substitute | :wait
    :affected_items,
    :customer_preference
  ]
end
```

### Events

```elixir
defmodule Accountex.Sales.Events.QuoteApproved do
  defstruct [
    :quote_id,
    :approval_timestamp,
    :approved_by,
    :approval_level,
    :approval_conditions,
    :valid_until
  ]
end

defmodule Accountex.Sales.Events.QuoteConvertedToOrder do
  defstruct [
    :quote_id,
    :order_id,
    :converted_items,
    :conversion_timestamp,
    :order_total,
    :payment_terms
  ]
end

defmodule Accountex.Sales.Events.CreditCheckCompleted do
  defstruct [
    :customer_id,
    :quote_id,
    :credit_approved,
    :approved_amount,
    :credit_limit,
    :existing_exposure,
    :credit_score,
    :payment_terms_assigned
  ]
end

defmodule Accountex.Sales.Events.QuoteExpired do
  defstruct [
    :quote_id,
    :expiration_date,
    :expiration_reason,
    :follow_up_required
  ]
end

defmodule Accountex.Sales.Events.OverbookingDetected do
  defstruct [
    :quote_id,
    :affected_items,
    :available_quantities,
    :requested_quantities,
    :resolution_required
  ]
end
```

### Aggregates

```elixir
defmodule Accountex.Sales.Aggregates.QuoteApprovalAggregate do
  defstruct [
    :quote_id,
    :status, # :draft | :pending_approval | :approved | :rejected | :expired | :converted
    :approval_chain,
    :current_approval_level,
    :pricing_validity,
    :credit_check_status,
    :inventory_reservations,
    :expiration_date,
    :version_number
  ]

  def execute(%__MODULE__{status: :pending_approval} = quote, %ApproveQuote{} = cmd) do
    cond do
      !has_approval_authority?(cmd.approved_by, quote.current_approval_level) ->
        {:error, :insufficient_authority}
      
      quote_expired?(quote) ->
        {:error, :quote_expired}
      
      needs_higher_approval?(quote, cmd) ->
        {quote |> advance_approval_level(),
         [%ApprovalLevelCompleted{
           quote_id: cmd.quote_id,
           level: quote.current_approval_level,
           next_level: quote.current_approval_level + 1
         }]}
      
      true ->
        {quote |> Map.put(:status, :approved),
         [%QuoteApproved{
           quote_id: cmd.quote_id,
           approved_by: cmd.approved_by,
           approval_level: cmd.approval_level
         }]}
    end
  end

  def execute(%__MODULE__{status: :approved} = quote, %ConvertQuoteToOrder{} = cmd) do
    with :ok <- validate_pricing_still_valid(quote),
         :ok <- validate_credit_approved(quote),
         :ok <- check_inventory_availability(cmd) do
      
      order_id = generate_order_id()
      
      events = [
        %QuoteConvertedToOrder{
          quote_id: cmd.quote_id,
          order_id: order_id,
          converted_items: cmd.selected_line_items || quote.line_items
        },
        %OrderCreated{
          order_id: order_id,
          customer_id: quote.customer_id,
          items: transform_quote_items_to_order_items(quote, cmd)
        }
      ]
      
      {quote |> Map.put(:status, :converted), events}
    end
  end

  defp needs_higher_approval?(quote, cmd) do
    approval_matrix = %{
      1 => %{max_discount: 20, max_value: 50_000},
      2 => %{max_discount: 30, max_value: 100_000},
      3 => %{max_discount: 40, max_value: 500_000},
      4 => %{max_discount: 100, max_value: :unlimited}
    }
    
    current_limits = approval_matrix[quote.current_approval_level]
    quote.discount_percentage > current_limits.max_discount ||
      quote.total_value > current_limits.max_value
  end
end
```

### Read Models/Projections

```elixir
defmodule Accountex.Sales.Projections.QuoteConversionProjection do
  use Commanded.Projections.Ecto, name: "quote_conversions"

  schema "quote_conversion_analytics" do
    field :period, :string
    field :total_quotes, :integer
    field :approved_quotes, :integer
    field :converted_quotes, :integer
    field :conversion_rate, :decimal
    field :average_approval_time, :integer # hours
    field :average_quote_value, :decimal
    field :win_loss_ratio, :decimal
    field :competitor_analysis, :map
  end
end

defmodule Accountex.Sales.Projections.CreditExposureProjection do
  use Commanded.Projections.Ecto, name: "customer_credit_exposure"

  schema "customer_credit_exposure" do
    field :customer_id, :string
    field :credit_limit, :decimal
    field :current_exposure, :decimal
    field :pending_orders, :decimal
    field :pending_quotes, :decimal
    field :available_credit, :decimal
    field :credit_score, :string
    field :payment_history_score, :integer
    field :last_credit_check, :utc_datetime
  end

  project %QuoteApproved{} = event, fn multi ->
    multi
    |> Ecto.Multi.run(:exposure, fn repo, _changes ->
      update_pending_exposure(repo, event.customer_id, event.quote_value)
    end)
  end
end
```

### Process Managers/Sagas

```elixir
defmodule Accountex.Sales.ProcessManagers.QuoteApprovalManager do
  use Commanded.ProcessManagers.ProcessManager,
    name: "quote_approval_process"

  defstruct [
    :quote_id,
    :approval_stage,
    :credit_check_completed,
    :inventory_checked,
    :pricing_validated,
    :approvals_received,
    :final_approval_pending
  ]

  def handle(%__MODULE__{} = state, %QuoteSubmittedForApproval{} = event) do
    [
      %PerformCreditCheck{
        customer_id: event.customer_id,
        quote_id: event.quote_id,
        requested_credit_amount: event.quote_value
      },
      %ValidatePricing{
        quote_id: event.quote_id,
        line_items: event.line_items
      },
      %CheckInventoryAvailability{
        quote_id: event.quote_id,
        requested_items: event.line_items
      }
    ]
  end

  def handle(%__MODULE__{credit_check_completed: true, 
                          inventory_checked: true,
                          pricing_validated: true} = state, 
            %ReadyForApproval{} = event) do
    %RouteToApprover{
      quote_id: event.quote_id,
      approval_level: determine_required_approval_level(event),
      approver: select_approver(event)
    }
  end

  def handle(%__MODULE__{} = state, %QuoteApproved{} = event) do
    if final_approval?(state, event) do
      %EnableQuoteConversion{
        quote_id: event.quote_id,
        valid_until: calculate_conversion_deadline(event)
      }
    else
      %RouteToNextApprover{
        quote_id: event.quote_id,
        current_level: event.approval_level,
        next_level: event.approval_level + 1
      }
    end
  end
end

defmodule Accountex.Sales.ProcessManagers.OverbookingManager do
  use Commanded.ProcessManagers.ProcessManager,
    name: "overbooking_handler"

  def handle(%__MODULE__{} = state, %OverbookingDetected{} = event) do
    strategy = determine_overbooking_strategy(event)
    
    case strategy do
      :backorder ->
        [%CreateBackorder{
          quote_id: event.quote_id,
          items: event.affected_items,
          expected_availability: estimate_availability_date(event.affected_items)
        }]
      
      :partial ->
        [%AllocateAvailableInventory{
          quote_id: event.quote_id,
          allocation_strategy: :proportional
        }]
      
      :substitute ->
        [%SuggestSubstituteProducts{
          quote_id: event.quote_id,
          original_items: event.affected_items
        }]
      
      :wait ->
        [%HoldQuoteForInventory{
          quote_id: event.quote_id,
          hold_until: calculate_hold_deadline()
        }]
    end
  end
end
```

### Business Rules and Constraints

```elixir
defmodule Accountex.Sales.Rules.QuoteApprovalRules do
  def approval_matrix do
    %{
      level_1: %{
        max_discount_percent: 20,
        max_order_value: 50_000,
        approvers: [:sales_manager]
      },
      level_2: %{
        max_discount_percent: 30,
        max_order_value: 100_000,
        approvers: [:regional_manager, :finance_manager]
      },
      level_3: %{
        max_discount_percent: 40,
        max_order_value: 500_000,
        approvers: [:sales_director, :cfo]
      },
      level_4: %{
        max_discount_percent: 100,
        max_order_value: :unlimited,
        approvers: [:ceo]
      }
    }
  end

  def quote_validity_periods do
    %{
      standard: 30, # days
      promotional: 14,
      government: 90,
      enterprise: 60,
      custom_manufacturing: 45
    }
  end

  def credit_check_rules do
    %{
      required_above: 10_000, # BR-SO-059
      soft_check_limit: 50_000, # BR-SO-060
      hard_check_required_above: 100_000, # BR-SO-061
      existing_customer_skip_threshold: 5_000, # BR-SO-062
      check_validity_days: 30 # BR-SO-063
    }
  end

  def overbooking_rules do
    %{
      max_overbooking_percentage: 110, # Can accept 10% more than available BR-SO-064
      backorder_acceptance_required: true, # BR-SO-065
      partial_shipment_minimum: 50, # percent BR-SO-066
      substitute_product_approval_required: true # BR-SO-067
    }
  end

  def conversion_rules do
    %{
      require_primary_quote: true, # BR-SO-068
      allow_partial_conversion: true, # BR-SO-069
      expired_quote_conversion: false, # BR-SO-070
      credit_recheck_threshold: 30 # days since last check BR-SO-071
    }
  end
end
```

## 7. Creating recurring sales orders process

### Commands

```elixir
defmodule Accountex.Sales.Commands.CreateRecurringOrder do
  defstruct [
    :customer_id,
    :template_id,
    :schedule_type, # :daily | :weekly | :monthly | :custom
    :schedule_config,
    :start_date,
    :end_date, # nil for indefinite
    :auto_renewal,
    :payment_method,
    :notification_preferences
  ]

  def validate(command) do
    with :ok <- validate_template(command),
         :ok <- validate_schedule(command),
         :ok <- validate_customer_credit(command),
         :ok <- validate_payment_method(command) do
      :ok
    end
  end
end

defmodule Accountex.Sales.Commands.ModifyRecurringSchedule do
  defstruct [
    :recurring_order_id,
    :new_schedule,
    :effective_date,
    :modify_future_orders_only,
    :reason
  ]
end

defmodule Accountex.Sales.Commands.SuspendRecurringOrder do
  defstruct [
    :recurring_order_id,
    :suspension_reason,
    :suspension_start_date,
    :suspension_end_date, # nil for indefinite
    :handle_pending_orders # :cancel | :fulfill | :hold
  ]
end
```

### Events

```elixir
defmodule Accountex.Sales.Events.RecurringOrderCreated do
  defstruct [
    :recurring_order_id,
    :customer_id,
    :template_id,
    :schedule,
    :start_date,
    :end_date,
    :auto_renewal_enabled,
    :next_order_date
  ]
end

defmodule Accountex.Sales.Events.RecurringOrderGenerated do
  defstruct [
    :recurring_order_id,
    :generated_order_id,
    :generation_date,
    :order_items,
    :order_total,
    :next_scheduled_date
  ]
end

defmodule Accountex.Sales.Events.RecurringOrderSuspended do
  defstruct [
    :recurring_order_id,
    :suspension_start,
    :suspension_end,
    :orders_affected,
    :suspension_reason
  ]
end

defmodule Accountex.Sales.Events.RecurringOrderRenewed do
  defstruct [
    :recurring_order_id,
    :old_end_date,
    :new_end_date,
    :renewal_terms,
    :auto_renewed
  ]
end
```

### Aggregates

```elixir
defmodule Accountex.Sales.Aggregates.RecurringOrderAggregate do
  defstruct [
    :recurring_order_id,
    :status, # :active | :suspended | :cancelled | :expired
    :template,
    :schedule,
    :next_generation_date,
    :orders_generated,
    :total_value_generated,
    :suspension_periods,
    :modifications_history
  ]

  def execute(%__MODULE__{} = recurring, %CreateRecurringOrder{} = cmd) do
    template = load_template(cmd.template_id)
    schedule = build_schedule(cmd.schedule_type, cmd.schedule_config)
    next_date = calculate_next_generation_date(schedule, cmd.start_date)
    
    {%__MODULE__{
      recurring_order_id: generate_id(),
      status: :active,
      template: template,
      schedule: schedule,
      next_generation_date: next_date,
      orders_generated: []
    },
    [%RecurringOrderCreated{
      recurring_order_id: recurring.recurring_order_id,
      template_id: cmd.template_id,
      schedule: schedule,
      next_order_date: next_date
    }]}
  end

  def execute(%__MODULE__{status: :active} = recurring, %GenerateScheduledOrder{}) do
    order = generate_order_from_template(recurring.template)
    next_date = calculate_next_generation_date(recurring.schedule, DateTime.utc_now())
    
    updated_recurring = recurring
    |> Map.put(:next_generation_date, next_date)
    |> Map.update(:orders_generated, [order.id], &[order.id | &1])
    
    {updated_recurring,
     [%RecurringOrderGenerated{
       recurring_order_id: recurring.recurring_order_id,
       generated_order_id: order.id,
       order_items: order.items,
       next_scheduled_date: next_date
     },
     %OrderCreated{
       order_id: order.id,
       customer_id: recurring.customer_id,
       source: {:recurring, recurring.recurring_order_id}
     }]}
  end

  def execute(%__MODULE__{status: :active} = recurring, %SuspendRecurringOrder{} = cmd) do
    suspension = %{
      start_date: cmd.suspension_start_date,
      end_date: cmd.suspension_end_date,
      reason: cmd.suspension_reason
    }
    
    updated = recurring
    |> Map.put(:status, :suspended)
    |> Map.update(:suspension_periods, [suspension], &[suspension | &1])
    
    {updated,
     [%RecurringOrderSuspended{
       recurring_order_id: recurring.recurring_order_id,
       suspension_start: cmd.suspension_start_date,
       suspension_end: cmd.suspension_end_date
     }]}
  end
end
```

### Process Managers/Sagas

```elixir
defmodule Accountex.Sales.ProcessManagers.RecurringOrderScheduler do
  use Commanded.ProcessManagers.ProcessManager,
    name: "recurring_order_scheduler"

  def handle(%__MODULE__{} = state, %RecurringOrderCreated{} = event) do
    %ScheduleNextGeneration{
      recurring_order_id: event.recurring_order_id,
      scheduled_for: event.next_order_date
    }
  end

  def handle(%__MODULE__{} = state, %ScheduledGenerationDue{} = event) do
    [
      %GenerateScheduledOrder{
        recurring_order_id: event.recurring_order_id
      },
      %ValidateCustomerCredit{
        customer_id: event.customer_id,
        order_amount: calculate_order_amount(event)
      },
      %CheckInventoryForRecurring{
        template_items: event.template_items
      }
    ]
  end

  def handle(%__MODULE__{} = state, %RecurringOrderGenerated{} = event) do
    %ScheduleNextGeneration{
      recurring_order_id: event.recurring_order_id,
      scheduled_for: event.next_scheduled_date
    }
  end

  def handle(%__MODULE__{} = state, %RecurringOrderExpiring{} = event) do
    if event.auto_renewal_enabled do
      %ProcessAutoRenewal{
        recurring_order_id: event.recurring_order_id,
        current_terms: event.current_terms
      }
    else
      %NotifyCustomerOfExpiration{
        recurring_order_id: event.recurring_order_id,
        expiration_date: event.end_date
      }
    end
  end
end
```

## 8. Creating blanket sales orders process

### Commands

```elixir
defmodule Accountex.Sales.Commands.CreateBlanketOrder do
  defstruct [
    :customer_id,
    :validity_period,
    :total_quantity_commitment,
    :minimum_release_quantity,
    :maximum_release_quantity,
    :pricing_terms,
    :delivery_schedule,
    :payment_terms,
    :penalty_clauses
  ]
end

defmodule Accountex.Sales.Commands.ReleaseBlanketOrder do
  defstruct [
    :blanket_order_id,
    :release_quantity,
    :requested_delivery_date,
    :shipping_instructions,
    :po_number,
    :release_type # :manual | :automatic | :scheduled
  ]
end
```

### Events

```elixir
defmodule Accountex.Sales.Events.BlanketOrderCreated do
  defstruct [
    :blanket_order_id,
    :customer_id,
    :total_commitment,
    :validity_period,
    :pricing_agreement,
    :minimum_commitment_percentage # typically 80%
  ]
end

defmodule Accountex.Sales.Events.BlanketOrderReleased do
  defstruct [
    :blanket_order_id,
    :release_id,
    :released_quantity,
    :remaining_quantity,
    :generated_order_id,
    :release_date
  ]
end

defmodule Accountex.Sales.Events.BlanketOrderDepleted do
  defstruct [
    :blanket_order_id,
    :final_release_date,
    :total_quantity_released,
    :commitment_fulfilled_percentage
  ]
end
```

### Aggregates

```elixir
defmodule Accountex.Sales.Aggregates.BlanketOrderAggregate do
  defstruct [
    :blanket_order_id,
    :status, # :active | :partially_released | :fully_released | :expired
    :total_commitment_quantity,
    :released_quantity,
    :remaining_quantity,
    :releases,
    :validity_period,
    :pricing_terms,
    :minimum_commitment_enforcement
  ]

  def execute(%__MODULE__{status: :active} = blanket, %ReleaseBlanketOrder{} = cmd) do
    cond do
      cmd.release_quantity > blanket.remaining_quantity ->
        {:error, :exceeds_remaining_quantity}
      
      cmd.release_quantity < blanket.minimum_release_quantity ->
        {:error, :below_minimum_release}
      
      true ->
        remaining = blanket.remaining_quantity - cmd.release_quantity
        new_status = if remaining == 0, do: :fully_released, else: :partially_released
        
        updated = blanket
        |> Map.put(:status, new_status)
        |> Map.put(:remaining_quantity, remaining)
        |> Map.update(:released_quantity, cmd.release_quantity, &(&1 + cmd.release_quantity))
        
        events = [
          %BlanketOrderReleased{
            blanket_order_id: cmd.blanket_order_id,
            released_quantity: cmd.release_quantity,
            remaining_quantity: remaining
          },
          %OrderCreated{
            order_id: generate_order_id(),
            source: {:blanket_release, cmd.blanket_order_id}
          }
        ]
        
        events = if new_status == :fully_released do
          events ++ [%BlanketOrderDepleted{
            blanket_order_id: cmd.blanket_order_id,
            total_quantity_released: updated.released_quantity
          }]
        else
          events
        end
        
        {updated, events}
    end
  end
end
```

### Process Managers/Sagas

```elixir
defmodule Accountex.Sales.ProcessManagers.BlanketOrderReleaseManager do
  use Commanded.ProcessManagers.ProcessManager,
    name: "blanket_release_manager"

  def handle(%__MODULE__{} = state, %BlanketOrderReleaseRequested{} = event) do
    [
      %ValidateReleaseQuantity{
        blanket_order_id: event.blanket_order_id,
        requested_quantity: event.quantity
      },
      %CheckDeliveryFeasibility{
        requested_date: event.delivery_date,
        items: event.items
      },
      %ConsolidateIfPossible{
        customer_id: event.customer_id,
        ship_to: event.ship_to_address
      }
    ]
  end

  def handle(%__MODULE__{} = state, %ApproachingMinimumCommitment{} = event) do
    %NotifyCustomerOfCommitment{
      blanket_order_id: event.blanket_order_id,
      current_percentage: event.fulfillment_percentage,
      required_percentage: event.minimum_commitment,
      deadline: event.validity_end_date
    }
  end
end
```

## 9. Integration points with other modules

```elixir
defmodule Accountex.Sales.Integrations.SystemIntegrations do
  @moduledoc """
  Central integration registry for all sales order processes
  """

  def inventory_management_integration do
    %{
      check_availability: "/inventory/availability",
      allocate_inventory: "/inventory/allocate",
      release_inventory: "/inventory/release",
      transfer_inventory: "/inventory/transfer",
      update_levels: "/inventory/update"
    }
  end

  def financial_integration do
    %{
      credit_check: "/finance/credit/check",
      invoice_generation: "/finance/invoice/create",
      refund_processing: "/finance/refund/process",
      payment_capture: "/finance/payment/capture",
      tax_calculation: "/finance/tax/calculate"
    }
  end

  def warehouse_management_integration do
    %{
      create_pick_task: "/wms/pick/create",
      cancel_pick_task: "/wms/pick/cancel",
      create_pack_task: "/wms/pack/create",
      generate_shipping_label: "/wms/shipping/label",
      update_bin_location: "/wms/location/update"
    }
  end

  def customer_relationship_integration do
    %{
      update_customer_profile: "/crm/customer/update",
      track_interaction: "/crm/interaction/create",
      update_credit_status: "/crm/credit/update",
      send_notification: "/crm/notification/send"
    }
  end

  def analytics_integration do
    %{
      track_conversion: "/analytics/conversion/track",
      update_metrics: "/analytics/metrics/update",
      generate_report: "/analytics/report/generate"
    }
  end
end
```

## Business rules summary

```elixir
defmodule Accountex.Sales.Rules.MasterRuleRegistry do
  @moduledoc """
  Consolidated business rules across all sales processes
  """

  def critical_thresholds do
    %{
      # Shipping
      partial_shipment_max: 5,
      over_shipment_tolerance: 10, # percent
      shipping_cutoff_time: ~T[17:00:00],
      
      # Cancellation
      cancellation_window_hours: 24,
      restocking_fee_max: 25, # percent
      bulk_cancel_limit: 50, # orders
      
      # Quote approval
      auto_approve_discount: 10, # percent
      auto_approve_value: 10_000,
      quote_validity_days: 30,
      
      # Credit
      credit_check_required_above: 5_000,
      credit_hold_threshold: 0.9, # 90% of limit
      
      # Recurring
      max_suspension_days: 90,
      renewal_notice_days: 30,
      
      # Blanket
      minimum_commitment: 80, # percent
      release_consolidation_window: 24 # hours
    }
  end

  def validation_requirements do
    %{
      mandatory_fields: [
        :customer_id,
        :order_items,
        :shipping_address,
        :payment_terms
      ],
      
      conditional_validations: [
        {:credit_check, "when order_value > 5000"}, # BR-SO-102
        {:manager_approval, "when discount > 20%"}, # BR-SO-103
        {:inventory_check, "when immediate_shipment = true"}, # BR-SO-104
        {:address_validation, "when international = true"} # BR-SO-105
      ],
      
      business_hours: %{
        monday: {~T[08:00:00], ~T[20:00:00]},
        tuesday: {~T[08:00:00], ~T[20:00:00]},
        wednesday: {~T[08:00:00], ~T[20:00:00]},
        thursday: {~T[08:00:00], ~T[20:00:00]},
        friday: {~T[08:00:00], ~T[20:00:00]},
        saturday: {~T[09:00:00], ~T[17:00:00]},
        sunday: :closed
      }
    }
  end

  def compliance_requirements do
    %{
      audit_retention_years: 7,
      pci_compliance: true,
      gdpr_compliance: true,
      sox_compliance: true,
      industry_specific: %{
        pharmaceutical: ["FDA", "DEA"],
        food: ["FDA", "USDA"],
        aerospace: ["ITAR", "EAR"],
        financial: ["FINRA", "SEC"]
      }
    }
  end
end
```

## Error handling patterns

```elixir
defmodule Accountex.Sales.ErrorHandling.CompensationActions do
  @moduledoc """
  Compensation and rollback strategies for failed operations
  """

  def compensation_registry do
    %{
      OrderShipped => [
        {:reverse, VoidShippingLabel},
        {:compensate, ReturnInventoryToStock},
        {:notify, AlertShippingManager}
      ],
      
      OrderCanceled => [
        {:reverse, ReinstateOrder},
        {:compensate, ReallocateInventory},
        {:notify, AlertCustomerService}
      ],
      
      QuoteConverted => [
        {:reverse, VoidGeneratedOrder},
        {:compensate, ReleaseAllocations},
        {:notify, AlertSalesTeam}
      ],
      
      RecurringOrderGenerated => [
        {:reverse, CancelGeneratedOrder},
        {:compensate, AdjustNextSchedule},
        {:notify, AlertCustomer}
      ],
      
      BlanketOrderReleased => [
        {:reverse, CancelRelease},
        {:compensate, RestoreCommitmentQuantity},
        {:notify, AlertAccountManager}
      ]
    }
  end

  def handle_saga_failure(saga_id, failed_step, error) do
    %CompensateSaga{
      saga_id: saga_id,
      failed_at_step: failed_step,
      error: error,
      compensation_strategy: determine_compensation_strategy(failed_step),
      retry_policy: %{
        max_attempts: 3,
        backoff: :exponential,
        initial_delay: 1000
      }
    }
  end

  def circuit_breaker_config do
    %{
      error_threshold: 5,
      timeout: 30_000,
      reset_timeout: 60_000,
      half_open_requests: 3
    }
  end
end
```

## Audit and compliance

```elixir
defmodule Accountex.Sales.Audit.ComplianceTracking do
  @moduledoc """
  Comprehensive audit trail for all sales operations
  """

  defstruct [
    :entity_id,
    :entity_type,
    :action,
    :actor_id,
    :timestamp,
    :changes,
    :ip_address,
    :session_id,
    :compliance_flags
  ]

  def track_event(event, metadata) do
    %__MODULE__{
      entity_id: extract_entity_id(event),
      entity_type: event.__struct__,
      action: extract_action(event),
      actor_id: metadata.actor_id,
      timestamp: metadata.timestamp,
      changes: extract_changes(event),
      ip_address: metadata.ip_address,
      session_id: metadata.session_id,
      compliance_flags: determine_compliance_requirements(event)
    }
  end

  def retention_policy do
    %{
      standard: 7, # years
      financial: 7,
      medical: 10,
      legal_hold: :indefinite
    }
  end
end
```

This completes the comprehensive business logic document for the Sales Order application part 2, covering all six requested processes with detailed commands, events, aggregates, projections, process managers, integrations, business rules, and error handling following event-sourced patterns using Ash and Commanded frameworks in Elixir.

# Accountex Sales Order Module Business Logic Requirements

## Elixir/Ash/Commanded Event-Sourcing Implementation

## Executive Summary

This document details the business logic requirements for implementing Accountex Sales Order module features based on analysis of corresponding functionality in enterprise ERP systems. The requirements focus on blanket sales order releases, import functionality, kit customization, advanced billing workflows, and reporting capabilities, structured for event-sourced architecture using Elixir, Ash framework, and Commanded CQRS/ES patterns.

## Chapter 9: Releasing Blanket Sales Order

### Core Business Logic

Blanket sales orders represent long-term contractual agreements between customers and sellers with predetermined terms, quantities, and pricing structures. The release process converts portions of these agreements into executable sales orders while maintaining contract integrity.

### Domain Model

```elixir
defmodule Accountex.SalesOrder.Aggregates.BlanketOrder do
  defstruct [
    :blanket_order_id,
    :customer_id,
    :contract_number,
    :contract_start_date,
    :contract_end_date,
    :total_contracted_quantity,
    :total_contracted_value,
    :released_quantity,
    :released_value,
    :remaining_quantity,
    :remaining_value,
    :pricing_terms,
    :discount_structure,
    :status,
    :releases
  ]
end
```

### Commands and Events

```elixir
# Commands
defmodule ReleaseBlanketOrder do
  defstruct [
    :blanket_order_id,
    :release_quantity,
    :requested_delivery_date,
    :shipping_warehouse,
    :special_instructions,
    :release_reference
  ]
end

# Events
defmodule BlanketOrderReleased do
  defstruct [
    :blanket_order_id,
    :release_id,
    :sales_order_id,
    :quantity_released,
    :value_released,
    :remaining_quantity,
    :remaining_value,
    :release_date,
    :requested_delivery_date
  ]
end

defmodule BlanketOrderFullyReleased do
  defstruct [
    :blanket_order_id,
    :total_releases,
    :completion_date
  ]
end

defmodule BlanketOrderExpired do
  defstruct [
    :blanket_order_id,
    :expiration_date,
    :unreleased_quantity,
    :unreleased_value
  ]
end
```

### Business Rules and Validations

**Release Validation Pipeline:**

1. **BR-SO-072: Contract Status Validation**: Verify blanket order is active and not expired
2. **BR-SO-073: Date Validation**: Ensure requested delivery date falls within contract period
3. **BR-SO-074: Quantity Validation**: Confirm release quantity doesn't exceed remaining contracted quantity
4. **BR-SO-075: Credit Validation**: Perform multi-stage credit limit checks with configurable enforcement
5. **BR-SO-076: Pricing Lock**: Apply contracted pricing and discounts to released order

```elixir
defmodule Accountex.SalesOrder.BlanketOrderReleasePolicy do
  def validate_release(blanket_order, release_command) do
    with :ok <- validate_contract_active(blanket_order),
         :ok <- validate_contract_period(blanket_order, release_command.requested_delivery_date),
         :ok <- validate_remaining_quantity(blanket_order, release_command.release_quantity),
         :ok <- validate_customer_credit(blanket_order.customer_id, calculate_release_value(blanket_order, release_command)),
         :ok <- validate_warehouse_availability(release_command.shipping_warehouse) do
      {:ok, :validated}
    else
      {:error, :contract_expired} -> {:error, "Blanket order has expired"}
      {:error, :invalid_delivery_date} -> {:error, "Delivery date outside contract period"}
      {:error, :insufficient_quantity} -> {:error, "Release quantity exceeds remaining contract quantity"}
      {:error, :credit_limit_exceeded} -> {:error, "Customer credit limit exceeded"}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### State Transitions

```
DRAFT -> ACTIVE -> PARTIALLY_RELEASED -> FULLY_RELEASED
                -> EXPIRED (time-based trigger)
                -> CANCELLED (manual action)
```

### Process Manager

```elixir
defmodule Accountex.SalesOrder.BlanketOrderReleaseProcess do
  use Commanded.ProcessManagers.ProcessManager
  
  def interested?(%BlanketOrderCreated{blanket_order_id: id}), do: {:start, id}
  def interested?(%BlanketOrderReleased{blanket_order_id: id}), do: {:continue, id}
  def interested?(%BlanketOrderFullyReleased{blanket_order_id: id}), do: {:stop, id}
  def interested?(%BlanketOrderExpired{blanket_order_id: id}), do: {:stop, id}
  
  def handle(%{}, %BlanketOrderReleased{} = event) do
    [
      %CreateSalesOrder{
        order_id: generate_order_id(),
        blanket_order_id: event.blanket_order_id,
        customer_id: event.customer_id,
        order_type: :blanket_release,
        locked_pricing: true
      },
      %UpdateBlanketOrderMetrics{
        blanket_order_id: event.blanket_order_id,
        released_quantity: event.quantity_released,
        released_value: event.value_released
      }
    ]
  end
end
```

## Chapter 10: Sales Order Import

### Core Business Logic

The import system provides automated bulk creation of sales orders from external sources with comprehensive validation, error handling, and audit capabilities.

### Import Aggregate

```elixir
defmodule Accountex.SalesOrder.Aggregates.ImportBatch do
  defstruct [
    :batch_id,
    :source_file,
    :import_template_id,
    :total_records,
    :processed_records,
    :successful_records,
    :failed_records,
    :validation_errors,
    :status,
    :initiated_by,
    :initiated_at
  ]
end
```

### Import Commands and Events

```elixir
# Commands
defmodule InitiateImport do
  defstruct [
    :batch_id,
    :source_file,
    :import_template_id,
    :validation_rules,
    :processing_options
  ]
end

defmodule ValidateImportRecord do
  defstruct [
    :batch_id,
    :record_index,
    :record_data,
    :validation_rules
  ]
end

# Events
defmodule ImportRecordValidated do
  defstruct [
    :batch_id,
    :record_index,
    :validation_status,
    :errors,
    :warnings,
    :normalized_data
  ]
end

defmodule ImportBatchCompleted do
  defstruct [
    :batch_id,
    :total_processed,
    :successful_imports,
    :failed_imports,
    :processing_time_ms
  ]
end
```

### Validation Rules Engine

```elixir
defmodule Accountex.SalesOrder.ImportValidation do
  def validate_import_record(record, template) do
    validators = [
      &validate_required_fields/2,
      &validate_customer_exists/2,
      &validate_items_exist/2,
      &validate_pricing_integrity/2,
      &validate_tax_codes/2,
      &validate_credit_limits/2,
      &validate_inventory_availability/2,
      &validate_currency_codes/2
    ]
    
    Enum.reduce_while(validators, {:ok, record}, fn validator, {:ok, data} ->
      case validator.(data, template) do
        {:ok, validated_data} -> {:cont, {:ok, validated_data}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end
  
  defp validate_credit_limits(record, _template) do
    case CreditManagement.check_credit_availability(record.customer_id, record.total_amount) do
      :approved -> {:ok, record}
      :hold -> {:ok, Map.put(record, :credit_status, :hold)}
      :rejected -> {:error, :credit_limit_exceeded}
    end
  end
end
```

### Import Processing Pipeline

```elixir
defmodule Accountex.SalesOrder.ImportProcessor do
  def process_import_batch(batch_id, records) do
    records
    |> Task.async_stream(&process_record/1, max_concurrency: 10, timeout: 5000)
    |> Enum.reduce(%{successful: [], failed: []}, fn
      {:ok, {:ok, order}}, acc -> 
        %{acc | successful: [order | acc.successful]}
      {:ok, {:error, error}}, acc -> 
        %{acc | failed: [error | acc.failed]}
      {:exit, reason}, acc ->
        %{acc | failed: [{:processing_error, reason} | acc.failed]}
    end)
  end
  
  defp process_record(record) do
    with {:ok, validated} <- validate_import_record(record),
         {:ok, normalized} <- normalize_data(validated),
         {:ok, order_id} <- create_sales_order(normalized) do
      {:ok, order_id}
    else
      error -> error
    end
  end
end
```

### Error Recovery and Audit

```elixir
defmodule Accountex.SalesOrder.ImportAudit do
  defstruct [
    :batch_id,
    :record_index,
    :original_data,
    :processed_data,
    :validation_results,
    :error_details,
    :retry_count,
    :final_status
  ]
end
```

## Chapter 11: Customized Kit Item Building

### Core Business Logic

Kit customization allows dynamic modification of kit components at the order level, enabling customer-specific configurations while maintaining pricing integrity and inventory tracking.

### Kit Domain Model

```elixir
defmodule Accountex.Inventory.KitDefinition do
  defstruct [
    :kit_id,
    :kit_name,
    :base_components,
    :optional_components,
    :substitution_rules,
    :pricing_method, # :fixed | :sum_of_components | :formula_based
    :assembly_instructions,
    :customization_allowed
  ]
end

defmodule Accountex.SalesOrder.CustomizedKit do
  defstruct [
    :order_id,
    :kit_id,
    :original_formula,
    :customized_formula,
    :component_modifications,
    :price_adjustments,
    :customization_reason,
    :approval_status
  ]
end
```

### Kit Customization Commands

```elixir
defmodule CustomizeKitComponents do
  defstruct [
    :order_id,
    :line_item_id,
    :kit_id,
    :modifications,
    :pricing_override
  ]
end

defmodule SubstituteKitComponent do
  defstruct [
    :order_id,
    :kit_id,
    :original_component_id,
    :substitute_component_id,
    :substitution_reason,
    :quantity_adjustment
  ]
end
```

### Kit Events

```elixir
defmodule KitCustomized do
  defstruct [
    :order_id,
    :kit_id,
    :original_components,
    :new_components,
    :price_impact,
    :customization_type
  ]
end

defmodule KitComponentSubstituted do
  defstruct [
    :order_id,
    :kit_id,
    :original_component,
    :substitute_component,
    :availability_status,
    :price_difference
  ]
end
```

### Kit Customization Business Rules

```elixir
defmodule Accountex.Kitting.CustomizationPolicy do
  def validate_customization(kit_definition, modifications) do
    with :ok <- validate_customization_allowed(kit_definition),
         :ok <- validate_component_compatibility(modifications),
         :ok <- validate_substitution_rules(kit_definition, modifications),
         :ok <- validate_inventory_availability(modifications),
         {:ok, new_price} <- recalculate_kit_price(kit_definition, modifications) do
      {:ok, %{modifications: modifications, new_price: new_price}}
    end
  end
  
  def recalculate_kit_price(kit_definition, modifications) do
    case kit_definition.pricing_method do
      :fixed -> 
        {:ok, kit_definition.base_price}
      
      :sum_of_components ->
        new_price = calculate_component_sum(modifications)
        {:ok, new_price}
      
      :formula_based ->
        new_price = apply_pricing_formula(kit_definition.pricing_formula, modifications)
        {:ok, new_price}
    end
  end
end
```

### Kit Assembly Tracking

```elixir
defmodule Accountex.Kitting.AssemblyTracker do
  defstruct [
    :kit_id,
    :order_id,
    :assembly_status,
    :components_allocated,
    :assembly_warehouse,
    :labor_time,
    :labor_cost,
    :completion_date
  ]
  
  def track_assembly(kit_customization) do
    %AssemblyStarted{
      kit_id: kit_customization.kit_id,
      order_id: kit_customization.order_id,
      components: kit_customization.customized_formula,
      started_at: DateTime.utc_now()
    }
  end
end
```

## Chapter 12: Advanced Billing Creation and Approval

### Core Business Logic

Advanced billing enables pre-shipment invoicing through pro-forma invoice creation, payment collection, and conversion to accounts receivable upon shipment approval.

### Advanced Billing Aggregate

```elixir
defmodule Accountex.Billing.AdvanceBill do
  defstruct [
    :advance_bill_id,
    :order_id,
    :customer_id,
    :billing_lines,
    :total_amount,
    :tax_amount,
    :payment_terms,
    :due_date,
    :status, # :draft | :pending_payment | :paid | :approved | :converted
    :payment_applications,
    :ar_invoice_id
  ]
end
```

### Billing Commands

```elixir
defmodule CreateAdvanceBill do
  defstruct [
    :order_id,
    :billing_lines,
    :payment_terms,
    :due_date,
    :early_payment_discount
  ]
end

defmodule ApplyPaymentToAdvanceBill do
  defstruct [
    :advance_bill_id,
    :payment_id,
    :payment_amount,
    :payment_method,
    :payment_date
  ]
end

defmodule ApproveAdvanceBill do
  defstruct [
    :advance_bill_id,
    :approved_by,
    :approval_notes,
    :shipment_reference
  ]
end
```

### Billing Events

```elixir
defmodule AdvanceBillCreated do
  defstruct [
    :advance_bill_id,
    :order_id,
    :customer_id,
    :total_amount,
    :due_date,
    :created_at
  ]
end

defmodule PaymentAppliedToAdvanceBill do
  defstruct [
    :advance_bill_id,
    :payment_id,
    :amount_applied,
    :remaining_balance,
    :payment_date
  ]
end

defmodule AdvanceBillConvertedToInvoice do
  defstruct [
    :advance_bill_id,
    :ar_invoice_id,
    :conversion_date,
    :carried_payments,
    :final_amount
  ]
end
```

### Approval Workflow

```elixir
defmodule Accountex.Billing.AdvanceBillApprovalProcess do
  use Commanded.ProcessManagers.ProcessManager
  
  def handle(%{status: :paid}, %ShipmentCompleted{order_id: order_id}) do
    %ApproveAdvanceBill{
      advance_bill_id: state.advance_bill_id,
      approved_by: :system,
      shipment_reference: event.shipment_id
    }
  end
  
  def handle(%{}, %AdvanceBillApproved{} = event) do
    %ConvertToARInvoice{
      advance_bill_id: event.advance_bill_id,
      invoice_date: Date.utc_today(),
      carry_forward_payments: true
    }
  end
end
```

### Payment Application Logic

```elixir
defmodule Accountex.Billing.PaymentApplication do
  def apply_payment_to_advance_bill(advance_bill, payment) do
    cond do
      payment.amount == advance_bill.remaining_balance ->
        {:full_payment, %{advance_bill | status: :paid, remaining_balance: 0}}
      
      payment.amount < advance_bill.remaining_balance ->
        {:partial_payment, %{advance_bill | 
          remaining_balance: advance_bill.remaining_balance - payment.amount,
          payment_applications: [payment | advance_bill.payment_applications]}}
      
      payment.amount > advance_bill.remaining_balance ->
        {:overpayment, %{advance_bill |
          status: :paid,
          remaining_balance: 0,
          credit_balance: payment.amount - advance_bill.remaining_balance}}
    end
  end
end
```

### Multi-Bill Line Item Support

```elixir
defmodule Accountex.Billing.MultiBillManager do
  def create_progressive_bills(order_id, billing_schedule) do
    billing_schedule
    |> Enum.map(fn schedule_item ->
      %CreateAdvanceBill{
        order_id: order_id,
        billing_lines: schedule_item.lines,
        amount: schedule_item.amount,
        due_date: schedule_item.due_date,
        milestone: schedule_item.milestone
      }
    end)
  end
end
```

## Chapters 13-14: Reporting Requirements

### Report Aggregation Infrastructure

```elixir
defmodule Accountex.Reporting.SalesOrderProjections do
  use Commanded.Projections.Ecto
  
  project %OrderCreated{} = event, metadata, fn multi ->
    projection = %SalesOrderSummary{
      order_id: event.order_id,
      customer_id: event.customer_id,
      order_date: event.created_at,
      total_amount: event.total_amount,
      status: "created"
    }
    
    Ecto.Multi.insert(multi, :order_summary, projection)
  end
  
  project %OrderShipped{} = event, _metadata, fn multi ->
    Ecto.Multi.update_all(multi, :update_summary,
      from(s in SalesOrderSummary, where: s.order_id == ^event.order_id),
      set: [status: "shipped", shipped_date: event.shipped_at])
  end
end
```

### Blanket Order Reports

```elixir
defmodule Accountex.Reports.BlanketOrderReports do
  def blanket_order_summary_report(filters \\ %{}) do
    query = from bo in BlanketOrderSummary,
      left_join: r in BlanketOrderRelease, on: r.blanket_order_id == bo.blanket_order_id,
      where: ^build_filters(filters),
      group_by: bo.blanket_order_id,
      select: %{
        blanket_order_id: bo.blanket_order_id,
        customer_name: bo.customer_name,
        contract_value: bo.total_contract_value,
        released_value: sum(r.release_amount),
        remaining_value: bo.total_contract_value - sum(r.release_amount),
        release_percentage: (sum(r.release_amount) / bo.total_contract_value) * 100,
        expiration_date: bo.contract_end_date,
        days_until_expiration: fragment("? - CURRENT_DATE", bo.contract_end_date)
      }
    
    Repo.all(query)
  end
  
  def released_blanket_order_detail(blanket_order_id) do
    query = from r in BlanketOrderRelease,
      where: r.blanket_order_id == ^blanket_order_id,
      order_by: [desc: r.release_date],
      select: %{
        release_id: r.release_id,
        sales_order_id: r.sales_order_id,
        release_date: r.release_date,
        quantity_released: r.quantity_released,
        amount_released: r.amount_released,
        delivery_date: r.requested_delivery_date,
        shipment_status: r.shipment_status
      }
    
    Repo.all(query)
  end
end
```

### Import Reports

```elixir
defmodule Accountex.Reports.ImportReports do
  def import_batch_summary(date_range \\ :today) do
    query = from ib in ImportBatch,
      where: ^date_filter(date_range),
      select: %{
        batch_id: ib.batch_id,
        imported_at: ib.initiated_at,
        total_records: ib.total_records,
        successful_imports: ib.successful_records,
        failed_imports: ib.failed_records,
        success_rate: (ib.successful_records / ib.total_records) * 100,
        processing_time: ib.processing_time_ms
      }
    
    Repo.all(query)
  end
  
  def import_error_analysis(batch_id) do
    query = from ie in ImportError,
      where: ie.batch_id == ^batch_id,
      group_by: ie.error_type,
      select: %{
        error_type: ie.error_type,
        error_count: count(ie.id),
        sample_records: fragment("array_agg(? ORDER BY ? LIMIT 5)", ie.record_index, ie.record_index)
      }
    
    Repo.all(query)
  end
end
```

### Advanced Billing Reports

```elixir
defmodule Accountex.Reports.AdvancedBillingReports do
  def pending_advance_bills_report do
    query = from ab in AdvanceBill,
      where: ab.status in ["pending_payment", "partially_paid"],
      left_join: p in PaymentApplication, on: p.advance_bill_id == ab.advance_bill_id,
      group_by: ab.advance_bill_id,
      select: %{
        advance_bill_id: ab.advance_bill_id,
        order_id: ab.order_id,
        customer_id: ab.customer_id,
        total_amount: ab.total_amount,
        paid_amount: coalesce(sum(p.amount), 0),
        remaining_amount: ab.total_amount - coalesce(sum(p.amount), 0),
        due_date: ab.due_date,
        days_overdue: fragment("GREATEST(0, CURRENT_DATE - ?)", ab.due_date)
      }
    
    Repo.all(query)
  end
  
  def advance_bill_conversion_metrics(date_range) do
    query = from ab in AdvanceBill,
      where: ab.converted_at >= ^date_range.start and ab.converted_at <= ^date_range.end,
      select: %{
        total_converted: count(ab.advance_bill_id),
        total_value_converted: sum(ab.total_amount),
        average_days_to_conversion: avg(fragment("? - ?", ab.converted_at, ab.created_at)),
        payment_collection_rate: avg(ab.paid_amount / ab.total_amount * 100)
      }
    
    Repo.one(query)
  end
end
```

### Kit Customization Reports

```elixir
defmodule Accountex.Reports.KitReports do
  def kit_customization_analysis do
    query = from kc in KitCustomization,
      join: k in Kit, on: k.kit_id == kc.kit_id,
      group_by: k.kit_id,
      select: %{
        kit_id: k.kit_id,
        kit_name: k.kit_name,
        total_orders: count(kc.order_id),
        customization_rate: avg(case when kc.customized then 1 else 0 end) * 100,
        common_substitutions: fragment("jsonb_agg(DISTINCT ?)", kc.component_substitutions),
        average_price_variance: avg(kc.price_adjustment)
      }
    
    Repo.all(query)
  end
end
```

### Real-time Dashboard Queries

```elixir
defmodule Accountex.Reports.DashboardQueries do
  use Commanded.Queries
  
  def sales_order_metrics do
    %{
      daily_orders: count_orders_by_date_range(:today),
      pending_shipments: count_pending_shipments(),
      credit_holds: count_credit_holds(),
      blanket_releases_today: count_blanket_releases(:today),
      import_success_rate: calculate_import_success_rate(:last_7_days),
      advance_bills_pending: sum_pending_advance_bills()
    }
  end
  
  defp count_orders_by_date_range(range) do
    from(o in OrderSummary,
      where: ^date_filter(range),
      select: count(o.order_id))
    |> Repo.one()
  end
end
```

## Event Store Configuration

```elixir
defmodule Accountex.EventStore do
  use EventStore, otp_app: :accountex
  
  def init(config) do
    config
    |> Keyword.put(:serializer, Commanded.Serialization.JsonSerializer)
    |> Keyword.put(:column_data_type, "jsonb")
    |> Keyword.put(:schema, "sales_order_events")
  end
end
```

## Ash Resource Definitions

```elixir
defmodule Accountex.SalesOrder.Order do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]
  
  attributes do
    uuid_primary_key :id
    attribute :order_number, :string, allow_nil?: false
    attribute :customer_id, :uuid, allow_nil?: false
    attribute :order_type, :atom, constraints: [one_of: [:standard, :blanket_release, :recurring]]
    attribute :status, :atom, default: :draft
    attribute :total_amount, :decimal, allow_nil?: false
    timestamps()
  end
  
  relationships do
    belongs_to :customer, Accountex.Customer
    belongs_to :blanket_order, Accountex.SalesOrder.BlanketOrder
    has_many :line_items, Accountex.SalesOrder.LineItem
    has_many :advance_bills, Accountex.Billing.AdvanceBill
  end
  
  actions do
    defaults [:read]
    
    create :create_from_import do
      argument :import_data, :map, allow_nil?: false
      change Accountex.Changes.ValidateImportData
      change Accountex.Changes.ApplyCreditCheck
    end
    
    update :release_from_blanket do
      argument :blanket_order_id, :uuid
      change Accountex.Changes.ApplyBlanketTerms
    end
  end
end
```

## Command Router Configuration

```elixir
defmodule Accountex.Router do
  use Commanded.Commands.Router
  
  identify Accountex.SalesOrder.Aggregates.BlanketOrder,
    by: :blanket_order_id
  
  dispatch [ReleaseBlanketOrder, ExpireBlanketOrder],
    to: Accountex.SalesOrder.BlanketOrderCommandHandler
  
  identify Accountex.SalesOrder.Aggregates.ImportBatch,
    by: :batch_id
    
  dispatch [InitiateImport, ProcessImportRecord, CompleteImportBatch],
    to: Accountex.SalesOrder.ImportCommandHandler
  
  identify Accountex.Kitting.Aggregates.CustomizedKit,
    by: :kit_customization_id
    
  dispatch [CustomizeKit, SubstituteComponent, ApproveCustomization],
    to: Accountex.Kitting.KitCustomizationHandler
end
```

## Conclusion

This comprehensive business logic specification provides the foundation for implementing Accountex Sales Order module features using Elixir, Ash framework, and Commanded event-sourcing. The architecture emphasizes clear separation of concerns, robust validation pipelines, and comprehensive audit trails while maintaining the flexibility required for complex ERP operations. Each component is designed to handle the specific business requirements identified in enterprise sales order management, with particular attention to maintaining data integrity and supporting complex workflows through event-driven patterns.

# Sales Orders Logic - Part 4

## 14. Reports Module Business Logic

### 14.1 Sales Tax Reports

#### 14.1.1 Entity Listing Reports

**Query: GetCurrencyCodeListing**

- Retrieves all currency codes with symbol descriptions
- Returns current exchange rates for each currency
- Includes GL Account ID assignments for foreign exchange gains/losses
- Validates proper GL account assignments for currency transactions
- Filters by active/inactive currency status

**Query: GetSalesTaxEntityListing**

- Returns all defined tax jurisdictions (federal, state, local)
- Displays tax rates for each entity
- Shows effective date ranges for tax rates
- Includes integration status with external tax services (TaxJar, AvaTax)
- Groups entities by geographic hierarchy

**Business Rules:**

- Tax entities can be combined into composite tax codes for overlapping jurisdictions
- **BR-SO-106:** Tax rates must have valid effective dates with no gaps in coverage
- Real-time tax queries override stored rates when external services are enabled
- Tax rate at time of shipment supersedes rate at time of order

#### 14.1.2 Tax Calculation Reports

**Query: GetTaxCalculationAudit**

- Retrieves detailed tax calculation history for transactions
- Shows jurisdiction breakdown for multi-jurisdictional taxes
- Includes exemption certificate application records
- Returns tax service API call logs when external services used
- Displays tax rate variance between order and shipment dates

**Command: RecalculateTaxForPeriod**

- Recalculates taxes for specified date range
- Updates tax liability based on current rates
- Generates adjustment entries for rate changes
- Creates compliance reports for tax authorities

**Events:**

- `TaxRateUpdated` - Triggered when tax rates change
- `TaxExemptionApplied` - When exemption certificate is used
- `TaxRecalculationCompleted` - After bulk recalculation process

### 14.2 Activity and System Reports

#### 14.2.1 Pay Code Reports

**Query: GetPayCodeListing**

- Returns all defined payment codes with descriptions
- Shows associated payment processing rules
- Includes C.O.D. tag generation requirements
- Displays payment method restrictions by customer type
- Returns usage statistics for each pay code

**Query: GetPayCodeUsageAnalysis**

- Analyzes payment code usage by period
- Groups by customer segment
- Shows payment success/failure rates
- Calculates average payment processing times
- Identifies payment method trends

#### 14.2.2 Bank Account Reports

**Query: GetBankAccountListing**

- Retrieves all configured bank accounts
- Returns account details (type, number, routing)
- Shows GL account mappings for each bank
- Includes currency assignments
- Filters by module availability (AP, AR, SO, Payroll)
- Returns balance reconciliation status

**Business Rules:**

- **BR-SO-107:** Bank accounts must have valid GL account assignments
- **BR-SO-108:** Currency must match for multi-currency transactions
- Accounts can be restricted to specific modules
- Routing numbers validated against banking standards

#### 14.2.3 Customer Activity Reports

**Query: GetCustomerActivitySummary**

- Aggregates all customer interactions by type
- Returns transaction counts and values by period
- Calculates customer lifetime value metrics
- Shows payment history and credit utilization
- Includes communication log summaries

**Query: GetCustomerRankingReport**

- Ranks customers by revenue (period and YTD)
- Calculates contribution margins per customer
- Identifies top performers by product category
- Shows year-over-year growth rates
- Returns customer concentration risk metrics

**Events:**

- `CustomerActivityThresholdReached` - When activity exceeds defined limits
- `CustomerStatusChanged` - When customer classification changes
- `CustomerRankingUpdated` - After periodic ranking recalculation

### 14.3 Report Generation Engine

#### 14.3.1 Report Filtering Logic

**Query: ApplyReportFilters**

- Supports individual record selection
- Enables range-based filtering (dates, codes, amounts)
- Allows include/exclude patterns
- Supports complex conditional logic (AND/OR/NOT)
- Enables saved filter sets for recurring reports

**Business Rules:**

- Date ranges validated against fiscal periods
- **BR-SO-109:** Filters must respect data access permissions
- Complex filters optimized for query performance
- Filter combinations tested for logical consistency

#### 14.3.2 Multi-Currency Report Processing

**Query: GenerateMultiCurrencyReport**

- Converts amounts using period-appropriate exchange rates
- Calculates currency gains/losses for period
- Provides both home and foreign currency columns
- Supports currency-specific subtotals
- Handles cross-currency consolidations

**Command: SetReportCurrencyParameters**

- Defines reporting currency for output
- Sets exchange rate source (current, historical, average)
- Configures gain/loss calculation methods
- Establishes rounding rules by currency

**Events:**

- `ExchangeRateVarianceDetected` - When rates differ significantly
- `CurrencyConversionCompleted` - After multi-currency processing
- `ReportGenerationCompleted` - When report finalized

#### 14.3.3 Report Output Management

**Query: GetReportFormats**

- Returns available export formats (Excel, PDF, CSV, XML)
- Shows format-specific options and limitations
- Includes template availability by format
- Returns compatibility requirements

**Command: ScheduleReportGeneration**

- Creates recurring report schedules
- Sets distribution lists and delivery methods
- Configures report parameters and filters
- Establishes retention policies

**Events:**

- `ReportScheduled` - When new schedule created
- `ReportGenerated` - After successful generation
- `ReportDistributed` - When report sent to recipients

## 15. Master Records Management Business Logic

### 15.1 Customer Master Records

#### 15.1.1 Customer Record Management

**Command: CreateCustomer**

- Validates customer data against account group rules
- Assigns customer number (internal or external)
- Sets default values from account group
- Creates audit trail entry
- Triggers duplicate checking logic
- Initializes credit management records

**Command: UpdateCustomer**

- Validates changes against business rules
- Updates modification timestamp and user
- Maintains change history log
- Propagates changes to related records
- Triggers credit review if credit terms changed
- Updates customer classification if criteria met

**Query: GetCustomerDetails**

- Returns complete customer profile
- Includes all addresses (bill-to, ship-to)
- Shows credit limit and current exposure
- Returns transaction history summary
- Includes contact information and preferences
- Displays national account relationships

**Events:**

- `CustomerCreated` - New customer added to system
- `CustomerUpdated` - Customer information modified
- `CreditLimitChanged` - Credit terms adjusted
- `CustomerArchived` - Customer marked as inactive

#### 15.1.2 Address Management

**Command: AddCustomerAddress**

- Validates address using postal authority data
- Geocodes address for mapping/routing
- Sets address type (billing, shipping, other)
- Establishes default address flags
- Links to tax jurisdictions

**Command: ValidateAddress**

- Performs real-time address verification
- Standardizes format per postal standards
- Returns confidence score
- Suggests corrections for invalid addresses
- Updates tax jurisdiction assignments

**Business Rules:**

- **BR-SO-110:** Each customer must have at least one billing address
- Shipping addresses validated for deliverability
- Address changes trigger tax recalculation
- Archived addresses retained for historical orders

#### 15.1.3 Credit Management

**Command: SetCreditLimit**

- Validates authorization level for change
- Creates approval workflow if exceeds threshold
- Updates credit insurance records
- Triggers credit hold review for existing orders
- Sends notifications to relevant parties

**Query: CalculateRemainingCredit**

- Computes current AR balance
- Adds unshipped order values
- Subtracts payments in transit
- Considers national account consolidation
- Returns available credit amount

**Business Rules:**

- Credit checks performed at order entry and release
- **BR-SO-111:** Temporary credit increases require expiration date
- **BR-SO-112:** Credit hold releases require authorization
- Parent company credit limits apply to subsidiaries

#### 15.1.4 National Account Management

**Command: EstablishNationalAccount**

- Creates parent-child relationships
- Sets consolidated billing preferences
- Defines payment distribution rules
- Establishes credit sharing parameters
- Configures statement consolidation

**Query: GetNationalAccountHierarchy**

- Returns complete account structure
- Shows credit utilization by entity
- Displays payment distribution history
- Calculates consolidated balances
- Returns activity by subsidiary

**Events:**

- `NationalAccountCreated` - Parent-child relationship established
- `SubsidiaryAdded` - New child account linked
- `ConsolidatedCreditExceeded` - Combined limit breached
- `PaymentDistributed` - Parent payment allocated to children

### 15.2 Inventory Master Records

#### 15.2.1 Item Record Management

**Command: CreateInventoryItem**

- Validates item code uniqueness
- Sets cost method (FIFO, LIFO, Average, Standard)
- Establishes units of measure
- Creates warehouse/bin assignments
- Initializes inventory quantities
- Sets up planning parameters

**Command: UpdateInventoryItem**

- Validates changes against open transactions
- Updates modification audit trail
- Recalculates planning parameters
- Adjusts safety stock levels
- Triggers cost recalculation if method changed

**Query: GetInventoryItemDetails**

- Returns complete item specifications
- Shows quantity by warehouse/bin
- Displays cost layers by method
- Includes substitute item relationships
- Returns upsell item associations
- Shows inventory activity history

**Business Rules:**

- Cost method changes restricted with quantity on hand
- **BR-SO-113:** Lot-controlled items require lot tracking setup
- Serialized items enforce unique serial numbers
- Kit items maintain component relationships

#### 15.2.2 Warehouse and Bin Configuration

**Command: ConfigureWarehouseBins**

- Creates warehouse location structure
- Sets bin capacity constraints
- Establishes picking priorities
- Defines zone assignments
- Configures cycle count parameters

**Query: GetBinAvailability**

- Returns available capacity by bin
- Shows current allocations
- Displays pending receipts
- Calculates optimal put-away locations
- Returns pick path optimization

**Business Rules:**

- **BR-SO-114:** Bin assignments respect item storage requirements
- **BR-SO-115:** Hazmat items require specialized locations
- Temperature-controlled zones enforce restrictions
- Cross-docking bins bypass storage

#### 15.2.3 Substitute and Upsell Management

**Command: DefineSubstituteItems**

- Creates substitution relationships
- Sets substitution priorities
- Defines substitution rules (automatic/manual)
- Establishes quantity conversion factors
- Links pricing relationships

**Command: ConfigureUpsellItems**

- Associates upsell opportunities with items
- Sets display priorities
- Defines commission structures
- Creates sales scripts
- Establishes bundling rules

**Query: GetSubstitutionOptions**

- Returns ranked substitute items
- Checks availability across warehouses
- Calculates price differences
- Shows customer-specific preferences
- Returns historical substitution success rates

**Events:**

- `ItemCreated` - New inventory item added
- `ItemUpdated` - Item specifications changed
- `SubstituteItemUsed` - Substitution executed
- `UpsellItemAdded` - Upsell item included in order
- `InventoryItemArchived` - Item marked as discontinued

#### 15.2.4 Lot and Serial Number Tracking

**Command: AssignLotNumbers**

- Generates lot numbers by rules
- Records manufacturing/expiration dates
- Links quality test results
- Maintains chain of custody
- Enables recall tracking

**Command: RegisterSerialNumber**

- Validates serial number uniqueness
- Links to specific inventory item
- Records warranty information
- Maintains service history
- Tracks ownership transfers

**Query: GetLotTraceability**

- Returns complete lot genealogy
- Shows all transactions for lot
- Displays current locations
- Returns quality history
- Provides recall impact analysis

**Business Rules:**

- FIFO enforcement for lot-controlled items
- **BR-SO-116:** Expiration date validation for perishables
- **BR-SO-117:** Serial numbers required at specific transaction points
- Lot mixing restrictions for certain items

### 15.3 Pricing and Discount Management

#### 15.3.1 Price List Management

**Command: CreatePriceList**

- Defines price list header information
- Sets effective date ranges
- Establishes currency assignments
- Creates customer group associations
- Configures approval requirements

**Command: SetItemPrices**

- Validates pricing against minimum margins
- Creates quantity break tiers
- Establishes promotional periods
- Sets contract pricing terms
- Implements price protection rules

**Query: GetApplicablePrices**

- Returns customer-specific pricing
- Calculates quantity break discounts
- Applies promotional pricing
- Considers contract terms
- Returns price history

**Business Rules:**

- Most specific price takes precedence
- Contract prices override list prices
- **BR-SO-118:** Promotional prices require valid dates
- **BR-SO-119:** Minimum price validation enforced
- **BR-SO-120:** Price changes require authorization based on impact

#### 15.3.2 Customer Pricing Groups

**Command: CreateCustomerPriceGroup**

- Defines group parameters
- Associates price lists
- Sets discount structures
- Establishes payment terms
- Configures credit policies

**Query: GetCustomerPriceGroupDetails**

- Returns group membership
- Shows associated pricing rules
- Displays discount matrices
- Returns usage statistics
- Shows profitability analysis

**Events:**

- `PriceListCreated` - New price list established
- `PricesUpdated` - Item prices modified
- `PromotionActivated` - Promotional pricing started
- `ContractPriceApplied` - Contract pricing used
- `CustomerPriceGroupChanged` - Customer reassigned to new group

## 16. Integration Points and Data Relationships

### 16.1 Report Integration Architecture

#### 16.1.1 Real-Time vs Batch Processing

**Query: DetermineProcessingMode**

- Evaluates data volume and complexity
- Considers system resource availability
- Checks business criticality
- Returns recommended processing mode
- Estimates completion time

**Command: ConfigureHybridProcessing**

- Sets real-time thresholds
- Defines batch scheduling windows
- Establishes fallback mechanisms
- Configures performance monitoring
- Creates escalation rules

**Business Rules:**

- Credit checks always real-time
- Inventory availability checks real-time during business hours
- Financial reports use batch processing for period-end
- Customer-facing queries prioritized for real-time

#### 16.1.2 Data Aggregation Patterns

**Command: ConfigureAggregationRules**

- Defines aggregation hierarchies
- Sets calculation methods
- Establishes refresh frequencies
- Creates materialized views
- Optimizes for query patterns

**Query: GetAggregatedData**

- Returns pre-calculated summaries
- Applies additional filters
- Performs drill-down operations
- Handles currency conversions
- Returns confidence indicators

**Events:**

- `AggregationCompleted` - Batch aggregation finished
- `MaterializedViewRefreshed` - Cached data updated
- `AggregationError` - Processing exception occurred

### 16.2 Module Integration Patterns

#### 16.2.1 Sales Order to Accounts Receivable

**Command: CreateARInvoice**

- Validates shipment completion
- Transfers customer data
- Applies payment terms
- Calculates due dates
- Creates GL distributions

**Query: GetARIntegrationStatus**

- Returns unposted shipments
- Shows invoice generation queue
- Displays posting errors
- Returns reconciliation variances
- Shows integration audit trail

**Events:**

- `InvoiceGenerated` - AR invoice created from SO
- `PaymentApplied` - Customer payment received
- `CreditMemoIssued` - Credit adjustment processed
- `IntegrationError` - Posting failure occurred

#### 16.2.2 Sales Order to Inventory Management

**Command: AllocateInventory**

- Reserves stock for order
- Updates available quantities
- Creates backorder records
- Triggers replenishment
- Adjusts safety stock

**Query: GetInventoryIntegrationData**

- Returns allocation status
- Shows reservation details
- Displays availability changes
- Returns cost layer impacts
- Shows perpetual inventory adjustments

**Events:**

- `InventoryAllocated` - Stock reserved for order
- `InventoryShipped` - Stock removed from inventory
- `BackorderCreated` - Insufficient stock available
- `InventoryReplenishmentTriggered` - Reorder point reached

#### 16.2.3 Sales Order to General Ledger

**Command: CreateGLEntries**

- Generates journal entries
- Validates account combinations
- Applies distribution rules
- Handles multi-currency postings
- Creates audit references

**Query: GetGLIntegrationStatus**

- Returns unposted transactions
- Shows GL batch status
- Displays validation errors
- Returns account reconciliation
- Shows period-end cutoff status

**Business Rules:**

- GL postings follow accrual or cash basis
- Multi-company transactions create intercompany entries
- Foreign currency transactions include revaluation
- All entries maintain balanced debits/credits

### 16.3 Event Sourcing Implementation

#### 16.3.1 Event Store Management

**Command: PublishDomainEvent**

- Validates event schema
- Assigns event sequence number
- Persists to event store
- Publishes to event bus
- Triggers event handlers

**Query: GetEventHistory**

- Returns events by aggregate
- Filters by event type
- Supports temporal queries
- Enables event replay
- Returns event metadata

**Business Rules:**

- Events are immutable once stored
- Event ordering preserved within aggregates
- Snapshots created at configurable intervals
- Event retention follows compliance requirements

#### 16.3.2 CQRS Implementation

**Command: UpdateWriteModel**

- Processes business commands
- Validates business rules
- Generates domain events
- Updates aggregate state
- Returns command result

**Query: UpdateReadModel**

- Consumes domain events
- Updates denormalized views
- Maintains query optimization
- Handles eventual consistency
- Provides fast query response

**Events:**

- `ReadModelUpdated` - Query model synchronized
- `ProjectionRebuilt` - Read model reconstructed
- `ConsistencyCheckFailed` - Data inconsistency detected

## 17. Validation Rules and Business Constraints

### 17.1 Master Data Validation

#### 17.1.1 Customer Validation Rules

**Command: ValidateCustomerData**

- **BR-SO-077:** Checks required fields by account group
- **BR-SO-078:** Validates credit limit reasonableness
- **BR-SO-079:** Verifies tax ID format
- **BR-SO-080:** Ensures address deliverability
- **BR-SO-081:** Checks payment term compatibility

**Business Rules:**

- **BR-SO-082:** Credit limits cannot exceed insurance coverage
- **BR-SO-083:** Tax-exempt status requires valid certificate
- **BR-SO-084:** International customers require additional documentation
- **BR-SO-085:** Duplicate customers detected by fuzzy matching
- **BR-SO-086:** Inactive customers cannot place new orders

#### 17.1.2 Inventory Validation Rules

**Command: ValidateInventoryData**

- Ensures item code uniqueness
- Validates cost method consistency
- Checks unit of measure conversions
- Verifies warehouse assignments
- Validates planning parameters

**Business Rules:**

- **BR-SO-087:** Safety stock must exceed minimum quantity
- **BR-SO-088:** Lead times validated against supplier performance
- **BR-SO-089:** Lot-controlled items require expiration tracking
- **BR-SO-090:** Serialized items enforce one-to-one tracking
- **BR-SO-091:** Kit components must be valid items

### 17.2 Transaction Validation

#### 17.2.1 Order Processing Validation

**Command: ValidateOrder**

- Verifies customer status
- Checks credit availability
- Validates pricing authorization
- Ensures inventory availability
- Confirms shipping feasibility

**Query: GetValidationErrors**

- Returns all validation failures
- Provides error severity levels
- Suggests corrective actions
- Shows override requirements
- Returns approval workflows

**Business Rules:**

- **BR-SO-092:** Orders cannot exceed customer credit limit without approval
- **BR-SO-093:** Minimum order quantities enforced
- **BR-SO-094:** Shipping dates validated against calendars
- **BR-SO-095:** Tax calculations verified against nexus rules
- **BR-SO-096:** Discounts require authorization above thresholds

#### 17.2.2 Financial Validation

**Command: ValidateFinancialData**

- Ensures balanced journal entries
- Validates account combinations
- Checks period status
- Verifies approval limits
- Confirms document support

**Business Rules:**

- **BR-SO-097:** Debits must equal credits
- **BR-SO-098:** Posting periods must be open
- **BR-SO-099:** Foreign currency requires exchange rates
- **BR-SO-100:** Intercompany transactions balance
- **BR-SO-101:** Supporting documents required for audit

### 17.3 Data Quality Management

#### 17.3.1 Data Cleansing Rules

**Command: CleanseData**

- Standardizes formatting
- Removes duplicate records
- Corrects common errors
- Fills missing values
- Updates outdated information

**Query: GetDataQualityMetrics**

- Returns completeness scores
- Shows accuracy measurements
- Displays consistency checks
- Returns timeliness indicators
- Shows validity percentages

**Events:**

- `DataCleansed` - Cleansing process completed
- `DuplicatesRemoved` - Duplicate records merged
- `DataQualityThresholdMet` - Quality targets achieved

#### 17.3.2 Referential Integrity

**Command: EnforceReferentialIntegrity**

- Validates foreign key relationships
- Prevents orphaned records
- Cascades updates appropriately
- Restricts deletions
- Maintains relationship consistency

**Business Rules:**

- Customer deletion restricted with open orders
- Item deletion prevented with inventory
- Price list deletion blocked if assigned
- Address deletion restricted for shipped orders
- Payment term deletion prevented if in use

### 17.4 Concurrency Control

#### 17.4.1 Locking Mechanisms

**Command: AcquireLock**

- Implements optimistic locking
- Uses version numbers
- Detects concurrent modifications
- Provides retry logic
- Escalates to pessimistic locking

**Query: GetLockStatus**

- Returns current locks
- Shows lock holders
- Displays wait queues
- Returns timeout status
- Shows deadlock detection

**Business Rules:**

- Master records use optimistic locking
- Financial transactions use pessimistic locking
- Inventory allocations use distributed locking
- Read operations non-blocking
- Lock timeouts configurable by transaction type

#### 17.4.2 Transaction Isolation

**Command: SetIsolationLevel**

- Configures read consistency
- Manages dirty reads
- Handles phantom reads
- Controls lock escalation
- Optimizes for workload

**Events:**

- `LockAcquired` - Resource locked successfully:
- `LockReleased` - Resource available
- `DeadlockDetected` - Circular dependency found
- `ConcurrencyConflict` - Simultaneous update attempted
- `TransactionRolledBack` - Consistency violation detected

## Integration Summary

The Reports Module and Master Records Management components form critical pillars of the Accountex Sales Order system. The Reports Module provides comprehensive business intelligence through real-time and batch processing capabilities, supporting multi-currency operations and complex filtering logic. The Master Records Management ensures data integrity through sophisticated validation rules, duplicate detection, and referential integrity constraints.

Key architectural patterns include:

- **Event Sourcing** for complete audit trails and temporal queries
- **CQRS** for optimized read/write operations
- **Hybrid Processing** for balancing real-time and batch requirements
- **Multi-level Validation** ensuring data quality at entry and processing
- **Sophisticated Integration** patterns enabling seamless module interaction

These components work together to provide a robust, scalable foundation for enterprise sales order processing while maintaining data consistency and regulatory compliance.

# Accountex Sales Orders Logic - Part 5: Master Records and Maintenance

## Overview

This document defines the business logic for master records and maintenance operations within the Accountex Sales Orders application. Following event-sourcing patterns with Commanded library and CQRS architecture, this part covers the essential master data that supports sales order processing while respecting the modular boundaries of the Accountex system.

## Master Record Ownership Model

The Sales Orders application operates within a bounded context that both owns specific master records and maintains read-model projections of shared master data from other modules. This design ensures data consistency while maintaining module independence.

### Records Owned by Sales Orders Module

- **Salesperson Records**: Commission tracking and sales attribution
- **Sales Territories**: Geographic and customer segment assignments
- **Sales-Specific Pricing Rules**: Override rules and special pricing
- **Order Remarks Templates**: Standardized comments and instructions
- **Customer Product Cross-References**: Customer-specific item identifiers
- **Sales Activity Types**: Sales process tracking definitions

### Shared Records (Referenced via Events)

- **Customer Master** (owned by Customer Management module)
- **Product Master** (owned by Inventory module)
- **Tax Entities and Codes** (owned by Finance module)
- **Currency Codes** (owned by Finance module)
- **Bank Accounts** (owned by Finance module)
- **Freight Carriers** (owned by Logistics module)

## Salesperson Master Records

Salesperson records manage sales attribution, commission calculations, and territory assignments within the sales organization.

### Commands and Events

```elixir
defmodule Accountex.SalesOrders.Commands.CreateSalesperson do
  @moduledoc """
  Command to create a new salesperson record
  
  ## Business Rules
  - **BR-SO-121:** Salesperson ID must be unique
  - **BR-SO-122:** Commission rate must be between 0 and 100
  - **BR-SO-123:** At least one territory must be assigned
  - **BR-SO-124:** Manager ID must reference existing salesperson if provided
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :salesperson_id, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false
    attribute :email, :string, allow_nil?: false
    attribute :commission_rate, :decimal, default: Decimal.new("0.00")
    attribute :commission_type, :atom, 
      constraints: [one_of: [:percentage, :flat_rate, :tiered]]
    attribute :territory_ids, {:array, Ash.Type.UUID}, default: []
    attribute :manager_id, Ash.Type.UUID
    attribute :active, :boolean, default: true
    attribute :effective_date, :date, allow_nil?: false
    attribute :metadata, :map, default: %{}
  end
  
  validations do
    validate present([:salesperson_id, :name, :email, :effective_date])
    validate {Accountex.Validators.UniqueIdentifier, 
      attribute: :salesperson_id, 
      scope: :tenant_id}
    validate {Accountex.Validators.CommissionRate, 
      attribute: :commission_rate,
      type: :commission_type}
  end
end

defmodule Accountex.SalesOrders.Events.SalespersonCreated do
  @moduledoc """
  Event emitted when a salesperson record is created
  
  ## Downstream Effects
  - Updates salesperson read models
  - Triggers territory assignment workflows
  - Initiates commission structure setup
  """
  
  use Ash.Resource,
    extensions: [AshEvents.Event]
  
  attributes do
    uuid_primary_key :id
    attribute :salesperson_id, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false
    attribute :email, :string, allow_nil?: false
    attribute :commission_rate, :decimal
    attribute :commission_type, :atom
    attribute :territory_ids, {:array, Ash.Type.UUID}
    attribute :manager_id, Ash.Type.UUID
    attribute :active, :boolean
    attribute :effective_date, :date
    attribute :occurred_at, :utc_datetime, default: &DateTime.utc_now/0
    attribute :metadata, :map
  end
end

defmodule Accountex.SalesOrders.Commands.UpdateCommissionStructure do
  @moduledoc """
  Command to update salesperson commission structure
  
  ## Business Rules
  - Changes take effect on specified effective date
  - Historical commission data preserved for reporting
  - Cannot reduce commission retroactively
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :salesperson_id, :string, allow_nil?: false
    attribute :commission_structure, :map, allow_nil?: false
    attribute :effective_date, :date, allow_nil?: false
    attribute :reason, :string
  end
  
  validations do
    validate {Accountex.Validators.FutureDate, 
      attribute: :effective_date,
      allow_today: true}
  end
end
```

### Salesperson Aggregate

```elixir
defmodule Accountex.SalesOrders.Aggregates.Salesperson do
  @moduledoc """
  Salesperson Aggregate - manages salesperson lifecycle and commission rules
  
  ## State Management
  - Tracks commission history with temporal validity
  - Manages territory assignments and transfers
  - Maintains sales quota assignments
  
  ## Invariants
  - **BR-SO-125:** Active salesperson required for new orders
  - **BR-SO-126:** Commission changes cannot be retroactive
  - **BR-SO-127:** Territory assignments must not overlap
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Aggregate, AshEvents.Events]
  
  commanded_aggregate do
    identity :salesperson_id
    
    command CreateSalesperson do
      handler &__MODULE__.handle_create_salesperson/2
    end
    
    command UpdateCommissionStructure do
      handler &__MODULE__.handle_update_commission/2
    end
    
    command AssignTerritory do
      handler &__MODULE__.handle_assign_territory/2
    end
    
    command DeactivateSalesperson do
      handler &__MODULE__.handle_deactivate/2
    end
  end
  
  defp handle_create_salesperson(nil, %CreateSalesperson{} = cmd) do
    %SalespersonCreated{
      salesperson_id: cmd.salesperson_id,
      name: cmd.name,
      email: cmd.email,
      commission_rate: cmd.commission_rate,
      commission_type: cmd.commission_type,
      territory_ids: cmd.territory_ids,
      manager_id: cmd.manager_id,
      active: true,
      effective_date: cmd.effective_date,
      metadata: cmd.metadata
    }
  end
  
  defp handle_update_commission(%{active: false}, _cmd) do
    {:error, :salesperson_inactive}
  end
  
  defp handle_update_commission(state, %UpdateCommissionStructure{} = cmd) do
    if Date.compare(cmd.effective_date, Date.utc_today()) == :lt do
      {:error, :cannot_backdate_commission}
    else
      %CommissionStructureUpdated{
        salesperson_id: state.salesperson_id,
        commission_structure: cmd.commission_structure,
        effective_date: cmd.effective_date,
        previous_structure: state.commission_structure,
        reason: cmd.reason
      }
    end
  end
end
```

## Sales Territory Management

Sales territories define geographic regions, customer segments, or product categories for sales organization and quota management.

### Territory Commands and Events

```elixir
defmodule Accountex.SalesOrders.Commands.DefineSalesTerritory do
  @moduledoc """
  Command to define a new sales territory
  
  ## Business Rules
  - **BR-SO-128:** Territory codes must be unique
  - **BR-SO-129:** Geographic boundaries must not overlap with same type
  - **BR-SO-130:** Parent territory must exist if specified
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :territory_code, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false
    attribute :type, :atom, 
      constraints: [one_of: [:geographic, :industry, :product_line, :customer_size]]
    attribute :parent_territory_id, Ash.Type.UUID
    attribute :boundaries, :map, allow_nil?: false
    attribute :quota_settings, :map, default: %{}
    attribute :active, :boolean, default: true
  end
  
  validations do
    validate present([:territory_code, :name, :type, :boundaries])
    validate {Accountex.Validators.TerritoryBoundaries, 
      attributes: [:type, :boundaries]}
  end
end

defmodule Accountex.SalesOrders.Events.SalesTerritoryDefined do
  use Ash.Resource,
    extensions: [AshEvents.Event]
  
  attributes do
    uuid_primary_key :id
    attribute :territory_code, :string
    attribute :name, :string
    attribute :type, :atom
    attribute :parent_territory_id, Ash.Type.UUID
    attribute :boundaries, :map
    attribute :quota_settings, :map
    attribute :active, :boolean
    attribute :occurred_at, :utc_datetime, default: &DateTime.utc_now/0
  end
end
```

## Customer Product Cross-References

Enables customers to use their own part numbers and descriptions when ordering, maintaining mappings to internal product codes.

### Cross-Reference Commands

```elixir
defmodule Accountex.SalesOrders.Commands.CreateCustomerProductReference do
  @moduledoc """
  Command to create customer-specific product reference
  
  ## Business Rules
  - **BR-SO-131:** Customer and product must exist
  - Customer part number unique per customer
  - **BR-SO-132:** Custom pricing requires approval if below minimum margin
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :customer_id, Ash.Type.UUID, allow_nil?: false
    attribute :product_id, Ash.Type.UUID, allow_nil?: false
    attribute :customer_part_number, :string, allow_nil?: false
    attribute :customer_description, :string
    attribute :customer_unit_of_measure, :string
    attribute :conversion_factor, :decimal, default: Decimal.new("1.00")
    attribute :contract_price, :decimal
    attribute :contract_valid_from, :date
    attribute :contract_valid_to, :date
    attribute :minimum_order_quantity, :integer
    attribute :notes, :string
  end
  
  validations do
    validate present([:customer_id, :product_id, :customer_part_number])
    validate {Accountex.Validators.DateRange, 
      attributes: [:contract_valid_from, :contract_valid_to]}
    validate {Accountex.Validators.PriceMargin, 
      attribute: :contract_price,
      context: [:product_id, :customer_id]}
  end
end

defmodule Accountex.SalesOrders.Aggregates.CustomerProductCatalog do
  @moduledoc """
  Aggregate for managing customer-specific product catalog
  
  ## Responsibilities
  - Maintain unique customer part numbers
  - Validate contract pricing against margins
  - Track historical pricing agreements
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Aggregate]
  
  commanded_aggregate do
    identity :customer_id
    
    command CreateCustomerProductReference do
      handler &__MODULE__.handle_create_reference/2
    end
    
    command UpdateContractPricing do
      handler &__MODULE__.handle_update_pricing/2
    end
    
    command ExpireReference do
      handler &__MODULE__.handle_expire_reference/2
    end
  end
  
  defp handle_create_reference(state, %CreateCustomerProductReference{} = cmd) do
    cond do
      reference_exists?(state, cmd.customer_part_number) ->
        {:error, :duplicate_customer_part_number}
      
      invalid_contract_dates?(cmd) ->
        {:error, :invalid_contract_period}
      
      true ->
        %CustomerProductReferenceCreated{
          customer_id: cmd.customer_id,
          product_id: cmd.product_id,
          customer_part_number: cmd.customer_part_number,
          customer_description: cmd.customer_description,
          contract_price: cmd.contract_price,
          contract_valid_from: cmd.contract_valid_from,
          contract_valid_to: cmd.contract_valid_to,
          metadata: build_reference_metadata(cmd)
        }
    end
  end
end
```

## Sales-Specific Pricing Rules

Manages pricing overrides, special discounts, and promotional pricing specific to sales operations.

### Pricing Rule Commands

```elixir
defmodule Accountex.SalesOrders.Commands.CreateSalesPricingRule do
  @moduledoc """
  Command to create sales-specific pricing rule
  
  ## Business Rules
  - Priority determines rule evaluation order
  - **BR-SO-133:** Date ranges must not overlap for same scope
  - **BR-SO-134:** Discount cannot exceed maximum allowed percentage
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :rule_code, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    attribute :rule_type, :atom,
      constraints: [one_of: [:discount_percentage, :fixed_price, :tier_pricing, :bundle]]
    attribute :scope, :map, allow_nil?: false  # {customer_group, product_category, etc}
    attribute :calculation, :map, allow_nil?: false
    attribute :priority, :integer, default: 100
    attribute :valid_from, :date, allow_nil?: false
    attribute :valid_to, :date
    attribute :requires_approval, :boolean, default: false
    attribute :minimum_quantity, :integer
    attribute :maximum_discount, :decimal
  end
  
  validations do
    validate present([:rule_code, :description, :rule_type, :scope, :calculation])
    validate {Accountex.Validators.PricingRuleConflict, 
      attributes: [:scope, :valid_from, :valid_to]}
    validate {Accountex.Validators.DiscountLimit, 
      attribute: :maximum_discount}
  end
end

defmodule Accountex.SalesOrders.Events.SalesPricingRuleCreated do
  use Ash.Resource,
    extensions: [AshEvents.Event]
  
  attributes do
    uuid_primary_key :id
    attribute :rule_code, :string
    attribute :rule_type, :atom
    attribute :scope, :map
    attribute :calculation, :map
    attribute :priority, :integer
    attribute :valid_from, :date
    attribute :valid_to, :date
    attribute :requires_approval, :boolean
    attribute :metadata, :map
    attribute :occurred_at, :utc_datetime, default: &DateTime.utc_now/0
  end
end
```

### Pricing Rule Aggregate

```elixir
defmodule Accountex.SalesOrders.Aggregates.PricingRuleEngine do
  @moduledoc """
  Aggregate for managing sales pricing rules
  
  ## Evaluation Order
  1. Customer-specific contract pricing
  2. Promotional rules by priority
  3. Volume-based tier pricing
  4. Standard pricing
  
  ## Conflict Resolution
  - Higher priority rules override lower
  - Most specific scope wins
  - **BR-SO-135:** Approval required for stacking
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Aggregate]
  
  commanded_aggregate do
    identity :tenant_id
    
    command CreateSalesPricingRule do
      handler &__MODULE__.handle_create_rule/2
    end
    
    command ActivatePromotionalPricing do
      handler &__MODULE__.handle_activate_promo/2
    end
    
    command EvaluatePricingForOrder do
      handler &__MODULE__.handle_evaluate_pricing/2
    end
  end
  
  defp handle_create_rule(state, %CreateSalesPricingRule{} = cmd) do
    with :ok <- validate_rule_conflicts(state, cmd),
         :ok <- validate_discount_limits(cmd),
         :ok <- validate_approval_requirements(cmd) do
      %SalesPricingRuleCreated{
        rule_code: cmd.rule_code,
        rule_type: cmd.rule_type,
        scope: cmd.scope,
        calculation: cmd.calculation,
        priority: cmd.priority,
        valid_from: cmd.valid_from,
        valid_to: cmd.valid_to,
        requires_approval: cmd.requires_approval,
        metadata: %{
          created_by: cmd.actor_id,
          minimum_quantity: cmd.minimum_quantity,
          maximum_discount: cmd.maximum_discount
        }
      }
    end
  end
end
```

## Order Remarks and Templates

Standardized comments and instructions for consistent order processing communication.

### Remarks Commands

```elixir
defmodule Accountex.SalesOrders.Commands.CreateRemarksTemplate do
  @moduledoc """
  Command to create standardized remarks template
  
  ## Business Rules
  - **BR-SO-136:** Template codes must be unique
  - Category determines where remarks appear
  - Active templates only available for selection
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :template_code, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    attribute :category, :atom,
      constraints: [one_of: [:shipping, :billing, :internal, :customer_facing, :warehouse]]
    attribute :remarks_text, :string, allow_nil?: false
    attribute :variables, {:array, :string}, default: []  # e.g., ["customer_name", "order_number"]
    attribute :active, :boolean, default: true
    attribute :auto_include_rules, :map, default: %{}  # Conditions for automatic inclusion
  end
  
  validations do
    validate present([:template_code, :description, :category, :remarks_text])
    validate {Accountex.Validators.TemplateVariables, 
      attributes: [:remarks_text, :variables]}
  end
end
```

## Sales Activity Types

Defines activity categories for tracking sales process stages and customer interactions.

### Activity Type Commands

```elixir
defmodule Accountex.SalesOrders.Commands.DefineSalesActivityType do
  @moduledoc """
  Command to define sales activity type
  
  ## Business Rules
  - **BR-SO-137:** Activity codes must be unique
  - Pipeline stage determines workflow position
  - Conversion metrics tracked for each type
  """
  
  use Ash.Resource,
    extensions: [AshCommanded.Command]
  
  attributes do
    uuid_primary_key :id
    attribute :activity_code, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false
    attribute :category, :atom,
      constraints: [one_of: [:prospecting, :qualification, :proposal, :negotiation, :closing]]
    attribute :pipeline_stage, :integer, allow_nil?: false
    attribute :expected_duration_days, :integer
    attribute :conversion_rate_target, :decimal
    attribute :required_fields, {:array, :string}, default: []
    attribute :next_activities, {:array, :string}, default: []  # Valid transitions
    attribute :active, :boolean, default: true
  end
  
  validations do
    validate present([:activity_code, :name, :category, :pipeline_stage])
    validate {Accountex.Validators.PipelineSequence, 
      attributes: [:pipeline_stage, :category]}
  end
end
```

## Read Model Projections

The Sales Orders module maintains read-optimized projections of both owned and referenced master data.

### Salesperson Summary Projection

```elixir
defmodule Accountex.SalesOrders.Projections.SalespersonSummary do
  @moduledoc """
  Read model for salesperson information and metrics
  
  ## Purpose
  - Quick lookup for order assignment
  - Commission calculation caching
  - Performance metrics aggregation
  
  ## Updated By
  - SalespersonCreated/Updated events
  - TerritoryAssigned events
  - OrderCompleted events (for metrics)
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshEvents.Events]
  
  postgres do
    table "sales_salesperson_summaries"
    repo Accountex.Repo
  end
  
  attributes do
    uuid_primary_key :id
    attribute :salesperson_id, :string, allow_nil?: false
    attribute :name, :string
    attribute :email, :string
    attribute :commission_rate, :decimal
    attribute :commission_type, :atom
    attribute :territories, {:array, :map}, default: []
    attribute :current_month_sales, :decimal, default: Decimal.new("0.00")
    attribute :current_quarter_sales, :decimal, default: Decimal.new("0.00")
    attribute :ytd_sales, :decimal, default: Decimal.new("0.00")
    attribute :active, :boolean
    attribute :last_order_date, :date
    attribute :updated_at, :utc_datetime
  end
  
  actions do
    read :by_territory do
      argument :territory_id, Ash.Type.UUID, allow_nil?: false
      filter expr(fragment("? @> ?", territories, ^[%{id: arg(:territory_id)}]))
    end
    
    read :active_only do
      filter expr(active == true)
    end
  end
end
```

### Customer Product Catalog Projection

```elixir
defmodule Accountex.SalesOrders.Projections.CustomerProductCatalog do
  @moduledoc """
  Read model for customer-specific product information
  
  ## Purpose
  - Fast lookup by customer part number
  - Contract pricing validation
  - Order entry optimization
  
  ## Updated By
  - CustomerProductReferenceCreated events
  - ContractPriceUpdated events
  - ProductMasterChanged events (from Inventory)
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer
  
  postgres do
    table "sales_customer_products"
    repo Accountex.Repo
    
    custom_indexes do
      index [:customer_id, :customer_part_number], unique: true
      index [:customer_id, :product_id]
    end
  end
  
  attributes do
    uuid_primary_key :id
    attribute :customer_id, Ash.Type.UUID, allow_nil?: false
    attribute :product_id, Ash.Type.UUID, allow_nil?: false
    attribute :customer_part_number, :string, allow_nil?: false
    attribute :customer_description, :string
    attribute :internal_product_code, :string  # Cached from Product master
    attribute :internal_description, :string  # Cached from Product master
    attribute :contract_price, :decimal
    attribute :contract_valid_from, :date
    attribute :contract_valid_to, :date
    attribute :standard_price, :decimal  # Cached for margin calculation
    attribute :available_quantity, :integer  # Cached from Inventory
    attribute :lead_time_days, :integer
    attribute :last_order_date, :date
    attribute :updated_at, :utc_datetime
  end
  
  calculations do
    calculate :contract_active, :boolean do
      expr(
        not is_nil(contract_valid_from) and 
        contract_valid_from <= today() and
        (is_nil(contract_valid_to) or contract_valid_to >= today())
      )
    end
    
    calculate :margin_percentage, :decimal do
      expr(
        if not is_nil(contract_price) and not is_nil(standard_price) and standard_price > 0 do
          (contract_price - standard_price) / standard_price * 100
        else
          nil
        end
      )
    end
  end
end
```

### Pricing Rule Evaluation Projection

```elixir
defmodule Accountex.SalesOrders.Projections.ActivePricingRules do
  @moduledoc """
  Read model for currently active pricing rules
  
  ## Purpose
  - Rapid price calculation during order entry
  - Rule conflict detection
  - Approval requirement checking
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer
  
  postgres do
    table "sales_active_pricing_rules"
    repo Accountex.Repo
  end
  
  attributes do
    uuid_primary_key :id
    attribute :rule_code, :string, allow_nil?: false
    attribute :rule_type, :atom
    attribute :scope_type, :atom  # :customer, :product, :category, :global
    attribute :scope_value, :string  # Specific ID or category
    attribute :calculation_method, :atom
    attribute :calculation_value, :decimal
    attribute :priority, :integer
    attribute :valid_from, :date
    attribute :valid_to, :date
    attribute :requires_approval, :boolean
    attribute :stacking_allowed, :boolean, default: false
    attribute :usage_count, :integer, default: 0
    attribute :last_used_date, :date
  end
  
  actions do
    read :applicable_rules do
      argument :customer_id, Ash.Type.UUID
      argument :product_id, Ash.Type.UUID
      argument :order_date, :date, default: &Date.utc_today/0
      
      filter expr(
        valid_from <= ^arg(:order_date) and
        (is_nil(valid_to) or valid_to >= ^arg(:order_date))
      )
      
      prepare fn query, _ ->
        # Complex filtering logic for applicable rules
        query
        |> Ash.Query.sort(priority: :desc)
      end
    end
  end
end
```

## Integration Event Handlers

The Sales Orders module subscribes to events from other bounded contexts to maintain its read models.

### Customer Master Event Handler

```elixir
defmodule Accountex.SalesOrders.EventHandlers.CustomerMasterHandler do
  @moduledoc """
  Handles customer-related events from Customer Management module
  
  ## Subscribed Events
  - CustomerCreated
  - CustomerUpdated
  - CustomerCreditLimitChanged
  - CustomerDeactivated
  """
  
  use Commanded.Event.Handler,
    application: Accountex.App,
    name: __MODULE__
  
  alias Accountex.CustomerManagement.Events.{
    CustomerCreated,
    CustomerUpdated,
    CustomerCreditLimitChanged,
    CustomerDeactivated
  }
  
  def handle(%CustomerCreated{} = event, _metadata) do
    # Update customer read models in sales context
    Accountex.SalesOrders.Projections.CustomerCache
    |> Ash.Changeset.for_create(:create, %{
      customer_id: event.customer_id,
      name: event.name,
      credit_limit: event.credit_limit,
      payment_terms: event.payment_terms,
      tax_entity_id: event.tax_entity_id,
      currency_code: event.currency_code,
      price_tier: event.price_tier,
      status: :active
    })
    |> Accountex.Repo.insert!()
    
    :ok
  end
  
  def handle(%CustomerCreditLimitChanged{} = event, _metadata) do
    # Update credit limit and potentially flag orders for review
    with {:ok, customer} <- get_customer_cache(event.customer_id) do
      customer
      |> Ash.Changeset.for_update(:update_credit_limit, %{
        credit_limit: event.new_credit_limit,
        credit_limit_updated_at: event.occurred_at
      })
      |> Accountex.Repo.update!()
      
      # Check pending orders against new limit
      check_pending_orders_credit(event.customer_id, event.new_credit_limit)
    end
    
    :ok
  end
end
```

### Product Master Event Handler

```elixir
defmodule Accountex.SalesOrders.EventHandlers.ProductMasterHandler do
  @moduledoc """
  Handles product-related events from Inventory module
  
  ## Subscribed Events
  - ProductCreated
  - ProductPriceChanged
  - ProductDiscontinued
  - InventoryLevelUpdated
  """
  
  use Commanded.Event.Handler,
    application: Accountex.App,
    name: __MODULE__
  
  def handle(%ProductPriceChanged{} = event, _metadata) do
    # Update product pricing in sales projections
    Accountex.SalesOrders.Projections.ProductPriceCache
    |> Ash.Query.filter(product_id == ^event.product_id)
    |> Accountex.Repo.update_all(
      set: [
        base_price: event.new_price,
        previous_price: event.old_price,
        price_updated_at: event.occurred_at
      ]
    )
    
    # Update customer product catalog with new standard prices
    update_customer_catalog_prices(event.product_id, event.new_price)
    
    :ok
  end
  
  def handle(%InventoryLevelUpdated{} = event, _metadata) do
    # Update available quantity in projections
    Accountex.SalesOrders.Projections.ProductAvailability
    |> Ash.Query.filter(product_id == ^event.product_id)
    |> Accountex.Repo.update_all(
      set: [
        available_quantity: event.available_quantity,
        allocated_quantity: event.allocated_quantity,
        availability_updated_at: event.occurred_at
      ]
    )
    
    :ok
  end
end
```

## Process Managers

Process managers orchestrate complex workflows involving master data maintenance across module boundaries.

### Salesperson Onboarding Process

```elixir
defmodule Accountex.SalesOrders.ProcessManagers.SalespersonOnboarding do
  @moduledoc """
  Orchestrates the complete onboarding process for new salesperson
  
  ## Process Steps
  1. Create salesperson record
  2. Assign territories
  3. Set up commission structure  
  4. Create system user account
  5. Assign customer accounts
  6. Configure approval limits
  """
  
  use Commanded.ProcessManagers.ProcessManager,
    application: Accountex.App,
    name: "SalespersonOnboarding"
  
  @derive Jason.Encoder
  defstruct [
    :salesperson_id,
    :onboarding_status,
    :territories_assigned,
    :user_account_created,
    :customers_assigned,
    :commission_configured
  ]
  
  def interested?(%SalespersonCreated{} = event), do: {:start, event.salesperson_id}
  def interested?(%TerritoryAssigned{} = event), do: {:continue, event.salesperson_id}
  def interested?(%UserAccountCreated{} = event), do: {:continue, event.salesperson_id}
  
  def handle(%__MODULE__{} = state, %SalespersonCreated{} = event) do
    %AssignTerritoriesToSalesperson{
      salesperson_id: event.salesperson_id,
      territory_ids: event.territory_ids,
      effective_date: event.effective_date
    }
  end
  
  def handle(%__MODULE__{} = state, %TerritoryAssigned{} = event) do
    state = %{state | territories_assigned: true}
    
    if onboarding_complete?(state) do
      %SalespersonOnboardingCompleted{
        salesperson_id: state.salesperson_id,
        completed_at: DateTime.utc_now()
      }
    else
      []
    end
  end
end
```

## Business Rules and Validations

### Commission Calculation Rules

```elixir
defmodule Accountex.SalesOrders.Rules.CommissionCalculator do
  @moduledoc """
  Business rules for salesperson commission calculations
  
  ## Commission Types
  - Percentage of sale amount
  - Flat rate per transaction
  - Tiered based on volume
  - Product-specific rates
  """
  
  def calculate_commission(order, salesperson) do
    base_commission = calculate_base_commission(order, salesperson)
    
    base_commission
    |> apply_territory_multiplier(order.territory_id)
    |> apply_product_adjustments(order.line_items)
    |> apply_volume_tier(salesperson.ytd_sales)
    |> apply_maximum_cap(salesperson.commission_cap)
  end
  
  defp calculate_base_commission(order, %{commission_type: :percentage} = salesperson) do
    Decimal.mult(order.total_amount, salesperson.commission_rate)
    |> Decimal.div(Decimal.new(100))
  end
  
  defp calculate_base_commission(order, %{commission_type: :flat_rate} = salesperson) do
    salesperson.commission_rate
  end
  
  defp apply_territory_multiplier(commission, territory_id) do
    multiplier = get_territory_multiplier(territory_id)
    Decimal.mult(commission, multiplier)
  end
end
```

### Pricing Evaluation Engine

```elixir
defmodule Accountex.SalesOrders.Rules.PricingEngine do
  @moduledoc """
  Evaluates and applies pricing rules in priority order
  
  ## Evaluation Sequence
  1. Customer contract pricing
  2. Promotional rules
  3. Volume discounts
  4. Standard pricing
  """
  
  def calculate_line_item_price(customer_id, product_id, quantity, order_date) do
    with {:ok, rules} <- get_applicable_rules(customer_id, product_id, order_date),
         {:ok, base_price} <- get_base_price(product_id),
         {:ok, contract_price} <- get_contract_price(customer_id, product_id, order_date) do
      
      price = contract_price || base_price
      
      rules
      |> Enum.sort_by(& &1.priority, :desc)
      |> Enum.reduce(price, fn rule, current_price ->
        apply_pricing_rule(rule, current_price, quantity)
      end)
      |> validate_minimum_price(base_price)
    end
  end
  
  defp apply_pricing_rule(%{rule_type: :discount_percentage} = rule, price, _quantity) do
    discount = Decimal.mult(price, rule.calculation_value)
    |> Decimal.div(Decimal.new(100))
    
    Decimal.sub(price, discount)
  end
  
  defp apply_pricing_rule(%{rule_type: :tier_pricing} = rule, _price, quantity) do
    find_tier_price(rule.calculation_value, quantity)
  end
end
```

## Data Migration and Versioning

### Event Versioning Strategy

```elixir
defmodule Accountex.SalesOrders.Events.Versioning do
  @moduledoc """
  Event versioning for master data evolution
  
  ## Version Management
  - Events include version number
  - Upcasters handle schema migrations
  - Backward compatibility maintained
  """
  
  defmodule SalespersonCreatedV2 do
    @moduledoc "Version 2 adds quota management fields"
    
    use Ash.Resource,
      extensions: [AshEvents.Event]
    
    attributes do
      # V1 attributes
      uuid_primary_key :id
      attribute :salesperson_id, :string
      attribute :name, :string
      attribute :commission_rate, :decimal
      
      # V2 additions
      attribute :monthly_quota, :decimal
      attribute :quarterly_quota, :decimal
      attribute :quota_currency, :string
      
      attribute :version, :integer, default: 2
    end
  end
  
  def upcast(%SalespersonCreatedV1{} = event) do
    %SalespersonCreatedV2{
      id: event.id,
      salesperson_id: event.salesperson_id,
      name: event.name,
      commission_rate: event.commission_rate,
      monthly_quota: Decimal.new("0.00"),
      quarterly_quota: Decimal.new("0.00"),
      quota_currency: "USD",
      version: 2
    }
  end
end
```

## Performance Optimizations

### Caching Strategy

```elixir
defmodule Accountex.SalesOrders.Cache.MasterDataCache do
  @moduledoc """
  In-memory caching for frequently accessed master data
  
  ## Cached Entities
  - Active salespersons
  - Common pricing rules
  - Customer product references
  """
  
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_salesperson(salesperson_id) do
    case :ets.lookup(:salesperson_cache, salesperson_id) do
      [{^salesperson_id, data}] -> {:ok, data}
      [] -> fetch_and_cache_salesperson(salesperson_id)
    end
  end
  
  def invalidate_salesperson(salesperson_id) do
    :ets.delete(:salesperson_cache, salesperson_id)
  end
  
  @impl true
  def init(_opts) do
    :ets.new(:salesperson_cache, [:set, :named_table, :public])
    :ets.new(:pricing_cache, [:set, :named_table, :public])
    schedule_cache_refresh()
    {:ok, %{}}
  end
end
```

## Audit and Compliance

### Master Data Change Tracking

```elixir
defmodule Accountex.SalesOrders.Audit.MasterDataAudit do
  @moduledoc """
  Comprehensive audit trail for master data changes
  
  ## Tracked Changes
  - All master record modifications
  - User and timestamp attribution
  - Before/after values
  - Business justification
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer
  
  postgres do
    table "sales_master_data_audit"
    repo Accountex.Repo
  end
  
  attributes do
    uuid_primary_key :id
    attribute :entity_type, :atom, allow_nil?: false
    attribute :entity_id, Ash.Type.UUID, allow_nil?: false
    attribute :action, :atom, allow_nil?: false
    attribute :actor_id, Ash.Type.UUID, allow_nil?: false
    attribute :actor_type, :atom  # :user, :system, :integration
    attribute :changes, :map, allow_nil?: false
    attribute :previous_values, :map
    attribute :justification, :string
    attribute :ip_address, :string
    attribute :session_id, Ash.Type.UUID
    attribute :performed_at, :utc_datetime, allow_nil?: false
  end
  
  actions do
    create :log_change do
      accept [:entity_type, :entity_id, :action, :changes]
      
      change set_context_from_actor()
      change validate_required_justification()
    end
  end
end
```

## Integration Specifications

### External System Synchronization

```elixir
defmodule Accountex.SalesOrders.Integration.MasterDataSync do
  @moduledoc """
  Synchronization patterns for external system integration
  
  ## Sync Strategies
  - Event-based real-time sync
  - Scheduled batch reconciliation
  - Conflict resolution rules
  """
  
  def sync_salesperson_to_crm(salesperson_id) do
    with {:ok, salesperson} <- get_salesperson(salesperson_id),
         {:ok, crm_payload} <- build_crm_payload(salesperson),
         {:ok, response} <- CRMClient.upsert_salesperson(crm_payload) do
      
      log_sync_success(salesperson_id, response.external_id)
      {:ok, response.external_id}
    else
      {:error, reason} ->
        log_sync_failure(salesperson_id, reason)
        schedule_retry(salesperson_id)
        {:error, reason}
    end
  end
end
```

## Conclusion

This master records and maintenance logic provides a comprehensive foundation for the Accountex Sales Orders module. The design respects bounded context boundaries while maintaining the flexibility needed for complex sales operations. The event-sourcing approach ensures complete audit trails and enables temporal queries, while CQRS patterns optimize both command processing and query performance.

The modular architecture allows the Sales Orders application to be deployed independently while maintaining consistency with other Accountex modules through well-defined event contracts and integration patterns.

# Accountex ERP Sales Order Application: Part 6 Business Logic Design

## Architecture patterns drive sophisticated order processing

The Accountex ERP system employs **event-sourcing with Commanded and AshCommanded**, combined with **Jido's agentic framework** for autonomous business logic execution. The modular architecture enables applications to operate independently while communicating through Phoenix.PubSub's internal event bus, replacing traditional message queues. Part 6 of the Sales Order business logic extends the established patterns from Part 5, focusing on advanced order processing including payment handling, fulfillment orchestration, and cross-module integration.

## Event-sourced payment processing with compensating transactions

Building on the established Commanded patterns, Part 6 introduces sophisticated payment processing with automatic rollback capabilities. The implementation leverages **process managers for multi-step payment workflows** and maintains complete audit trails through event sourcing:

```elixir
defmodule Accountex.Sales.Aggregates.PaymentProcessor do
  defstruct [:order_id, :payment_status, :payment_attempts, :authorized_amount]

  # Command handler for payment authorization
  def execute(%__MODULE__{payment_status: nil}, %Accountex.Commands.AuthorizePayment{} = cmd) do
    %Accountex.Events.PaymentAuthorizationRequested{
      order_id: cmd.order_id,
      payment_method: cmd.payment_method,
      amount: cmd.amount,
      authorization_id: UUID.uuid4(),
      metadata: %{
        customer_id: cmd.customer_id,
        retry_attempt: 1
      }
    }
  end

  # Compensating transaction for failed payments
  def execute(%__MODULE__{payment_status: :authorized}, %Accountex.Commands.ReversePayment{} = cmd) do
    %Accountex.Events.PaymentReversed{
      order_id: cmd.order_id,
      reversal_reason: cmd.reason,
      reversed_amount: cmd.amount,
      timestamp: DateTime.utc_now()
    }
  end

  # State evolution from events
  def apply(%__MODULE__{} = state, %Accountex.Events.PaymentAuthorizationRequested{} = event) do
    %__MODULE__{state | 
      payment_status: :pending_authorization,
      payment_attempts: (state.payment_attempts || 0) + 1
    }
  end
end

defmodule Accountex.ProcessManagers.PaymentOrchestrator do
  use Commanded.ProcessManagers.ProcessManager,
    application: Accountex.CommandedApplication,
    name: "PaymentOrchestrator"

  defstruct [:order_id, :payment_state, :retry_count, :timeout_at]

  # Orchestrate payment with automatic retries and timeout handling
  def handle(%__MODULE__{} = state, %Accountex.Events.OrderConfirmed{} = event) do
    [
      %Accountex.Commands.ValidatePaymentMethod{
        order_id: event.order_id,
        customer_id: event.customer_id
      },
      %Accountex.Commands.AuthorizePayment{
        order_id: event.order_id,
        amount: event.total_amount,
        payment_method: event.payment_method
      }
    ]
  end

  # Implement circuit breaker pattern for payment gateway
  def handle(%__MODULE__{retry_count: count} = state, %Accountex.Events.PaymentFailed{} = event) when count < 3 do
    Process.send_after(self(), {:retry_payment, event.order_id}, :timer.seconds(count * 5))
    []
  end

  def handle(%__MODULE__{retry_count: 3}, %Accountex.Events.PaymentFailed{} = event) do
    [%Accountex.Commands.CancelOrder{
      order_id: event.order_id,
      reason: "Payment authorization failed after maximum retries"
    }]
  end
end
```

## Agentic fulfillment coordination across distributed modules

The Jido framework enables **intelligent agents to coordinate fulfillment** across multiple optional modules that may or may not be available at runtime. Agents dynamically discover available services and adapt their workflows accordingly:

```elixir
defmodule Accountex.Agents.FulfillmentCoordinator do
  use Jido.Agent,
    name: "fulfillment_coordinator",
    description: "Orchestrates order fulfillment across inventory, warehouse, and shipping modules"

  # Adaptive fulfillment planning based on available modules
  def plan_fulfillment(%{order: order, available_modules: modules}) do
    base_instructions = [
      %Jido.Instruction{
        action: "validate_fulfillment_readiness",
        params: %{order_id: order.id}
      }
    ]

    inventory_instructions = if :inventory in modules do
      [%Jido.Instruction{
        action: "allocate_inventory",
        params: %{line_items: order.line_items},
        fallback: %{action: "backorder_items"}
      }]
    else
      []
    end

    warehouse_instructions = if :warehouse in modules do
      [%Jido.Instruction{
        action: "create_pick_pack_instructions",
        params: %{order: order, priority: calculate_priority(order)}
      }]
    else
      [%Jido.Instruction{
        action: "manual_fulfillment_notification",
        params: %{order_id: order.id}
      }]
    end

    {:ok, base_instructions ++ inventory_instructions ++ warehouse_instructions}
  end

  # Signal handling for cross-module events
  def handle_signal(%{type: "inventory.allocation_complete"} = signal, opts) do
    order_id = signal.data.order_id
    
    # Coordinate with warehouse module if available
    case check_module_availability(:warehouse) do
      true -> 
        dispatch_warehouse_instructions(order_id, signal.data.allocated_items)
      false ->
        # Fallback to manual processing
        notify_fulfillment_team(order_id)
    end
  end

  defp check_module_availability(module) do
    Phoenix.PubSub.broadcast(
      Accountex.PubSub,
      "module_discovery",
      {:check_availability, module}
    )
    
    receive do
      {:module_available, ^module} -> true
      {:module_unavailable, ^module} -> false
    after
      100 -> false
    end
  end
end

defmodule Accountex.Actions.AllocateInventory do
  use Jido.Action,
    name: "allocate_inventory",
    schema: [
      line_items: [type: {:list, :map}, required: true],
      allocation_strategy: [type: :atom, default: :fifo]
    ]

  def run(%{line_items: items, allocation_strategy: strategy}, context) do
    # Multi-warehouse allocation logic
    allocations = Enum.map(items, fn item ->
      warehouses = get_available_warehouses()
      
      case allocate_from_warehouses(item, warehouses, strategy) do
        {:ok, allocation} -> allocation
        {:partial, allocation, shortage} -> 
          handle_shortage(allocation, shortage, context)
        {:error, :out_of_stock} ->
          trigger_procurement(item)
      end
    end)

    {:ok, %{allocations: allocations, status: determine_allocation_status(allocations)}}
  end

  defp handle_shortage(allocation, shortage, context) do
    # Intelligent shortage handling with customer preferences
    customer_preferences = context.customer_context.preferences
    
    cond do
      customer_preferences.allow_partial_shipment ->
        %{allocation | status: :partial_fulfillment}
      customer_preferences.allow_backorder ->
        create_backorder(shortage)
      true ->
        %{allocation | status: :awaiting_stock}
    end
  end
end
```

## Advanced shipping calculations with multi-carrier optimization

Part 6 implements **sophisticated shipping logic** that integrates with multiple carriers and optimizes based on cost, speed, and reliability metrics:

```elixir
defmodule Accountex.Sales.ShippingEngine do
  use Ash.Resource,
    domain: Accountex.Sales,
    extensions: [AshCommanded]

  actions do
    action :calculate_optimal_shipping, :map do
      argument :order, :map, allow_nil?: false
      argument :delivery_requirements, :map, allow_nil?: false
      
      run fn input, _context ->
        order = input.arguments.order
        requirements = input.arguments.delivery_requirements
        
        # Multi-carrier rate shopping
        carrier_options = 
          [:fedex, :ups, :usps, :dhl]
          |> Task.async_stream(fn carrier ->
            calculate_carrier_rates(carrier, order, requirements)
          end, timeout: 5000)
          |> Enum.reduce([], fn 
            {:ok, {:ok, rates}}, acc -> acc ++ rates
            _, acc -> acc
          end)
        
        # Apply business rules for carrier selection
        optimal_option = select_optimal_carrier(
          carrier_options, 
          requirements.priority,
          order.customer_tier
        )
        
        {:ok, %{
          selected_carrier: optimal_option.carrier,
          shipping_cost: optimal_option.cost,
          estimated_delivery: optimal_option.delivery_date,
          tracking_method: optimal_option.tracking_type,
          alternative_options: filter_alternatives(carrier_options, optimal_option)
        }}
      end
    end

    update :apply_shipping_calculation do
      accept [:shipping_carrier, :shipping_cost, :estimated_delivery]
      
      change fn changeset, _context ->
        # Update order with shipping details
        changeset
        |> Ash.Changeset.change_attribute(:shipping_confirmed, true)
        |> Ash.Changeset.change_attribute(:fulfillment_status, :ready_to_ship)
        |> notify_warehouse_of_shipping_method()
      end
      
      validate shipping_cost_within_limits()
    end
  end

  defp select_optimal_carrier(options, priority, customer_tier) do
    weighted_options = Enum.map(options, fn option ->
      score = calculate_carrier_score(option, priority, customer_tier)
      {option, score}
    end)
    
    {best_option, _score} = Enum.max_by(weighted_options, fn {_option, score} -> score end)
    best_option
  end

  defp calculate_carrier_score(option, priority, customer_tier) do
    base_score = 100
    
    # Cost weight: 40% for standard, 20% for expedited
    cost_weight = if priority == :expedited, do: 0.2, else: 0.4
    cost_score = (100 - (option.cost / option.max_cost * 100)) * cost_weight
    
    # Speed weight: 20% for standard, 50% for expedited
    speed_weight = if priority == :expedited, do: 0.5, else: 0.2
    days_to_delivery = Date.diff(option.delivery_date, Date.utc_today())
    speed_score = (100 - (days_to_delivery * 10)) * speed_weight
    
    # Reliability weight: 40% for premium customers, 20% for standard
    reliability_weight = if customer_tier == :premium, do: 0.4, else: 0.2
    reliability_score = option.carrier_reliability_rating * reliability_weight
    
    cost_score + speed_score + reliability_score
  end
end
```

## Cross-module integration with graceful degradation

The architecture ensures **robust operation even when dependent modules are unavailable** through intelligent fallback mechanisms:

```elixir
defmodule Accountex.Sales.ModuleIntegration do
  use GenServer

  # Dynamic module discovery and health checking
  def check_and_integrate(order_id, required_modules) do
    available = discover_available_modules(required_modules)
    missing = required_modules -- available
    
    integration_plan = build_integration_plan(available, missing)
    execute_integration(order_id, integration_plan)
  end

  defp build_integration_plan(available, missing) do
    %{
      accounting: handle_accounting_integration(available),
      inventory: handle_inventory_integration(available),
      crm: handle_crm_integration(available),
      fallbacks: generate_fallbacks(missing)
    }
  end

  defp handle_accounting_integration(available) do
    if :accounting in available do
      %{
        strategy: :direct_integration,
        actions: [
          {:create_journal_entry, :async},
          {:update_accounts_receivable, :sync},
          {:calculate_tax, :sync}
        ]
      }
    else
      %{
        strategy: :event_queue,
        actions: [
          {:queue_journal_entry, :async},
          {:estimate_tax, :local}
        ]
      }
    end
  end

  # Event-based communication without external message queues
  def broadcast_order_event(event_type, order_data) do
    enriched_event = %{
      event_type: event_type,
      order: order_data,
      timestamp: DateTime.utc_now(),
      source_module: :sales_order,
      correlation_id: UUID.uuid4()
    }
    
    # Use Phoenix.PubSub for internal event distribution
    Phoenix.PubSub.broadcast(
      Accountex.PubSub,
      "order_events",
      {:order_event, enriched_event}
    )
    
    # Store event for modules that are temporarily offline
    Accountex.EventStore.persist_for_replay(enriched_event)
  end
end

defmodule Accountex.Sales.IntegrationHandlers do
  # Handle responses from other modules asynchronously
  def handle_info({:module_response, :accounting, response}, state) do
    case response do
      {:ok, :journal_entry_created} ->
        update_order_financial_status(state.order_id, :posted)
      {:error, :module_unavailable} ->
        queue_for_retry(state.order_id, :accounting, :journal_entry)
    end
    {:noreply, state}
  end

  # Implement saga pattern for distributed transactions
  def handle_complex_integration(order) do
    saga = %Accountex.Sagas.OrderFulfillment{
      order_id: order.id,
      steps: [
        {:verify_payment, :required},
        {:allocate_inventory, :required},
        {:create_shipping_label, :optional},
        {:update_accounting, :eventually_consistent},
        {:notify_customer, :best_effort}
      ]
    }
    
    Accountex.SagaOrchestrator.execute(saga)
  end
end
```

## Business rules engine with declarative validation chains

Part 6 introduces **complex business rule evaluation** that can be configured without code changes:

```elixir
defmodule Accountex.Sales.BusinessRules do
  use Ash.Resource,
    extensions: [AshCommanded]

  # Declarative rule definitions
  validations do
    validate {Accountex.Rules.OrderValueLimit, 
      max_value: 50000, 
      customer_tier: :standard}
    
    validate {Accountex.Rules.ShippingAddressVerification,
      verification_level: :strict,
      allowed_countries: ["US", "CA", "MX"]}
    
    validate {Accountex.Rules.FraudDetection,
      risk_threshold: 0.7,
      check_velocity: true}
  end

  changes do
    change {Accountex.Changes.ApplyDiscountRules, 
      rules: [
        {:volume_discount, min_quantity: 100, discount: 0.10},
        {:loyalty_discount, min_orders: 10, discount: 0.05},
        {:seasonal_promotion, valid_until: ~D[2025-12-31], discount: 0.15}
      ]}
    
    change {Accountex.Changes.CalculateTaxes,
      tax_engine: :avalara,
      fallback: :internal_calculator}
  end
end

defmodule Accountex.Rules.FraudDetection do
  use Ash.Resource.Validation

  def validate(changeset, opts, context) do
    order = changeset.data
    risk_score = calculate_fraud_risk(order, context.customer_history)
    
    cond do
      risk_score > opts[:risk_threshold] ->
        {:error, field: :base, 
         message: "Order flagged for manual review", 
         metadata: %{risk_score: risk_score}}
      
      risk_score > (opts[:risk_threshold] * 0.8) ->
        # Add to review queue but allow processing
        queue_for_review(order.id, risk_score)
        :ok
      
      true -> :ok
    end
  end

  defp calculate_fraud_risk(order, history) do
    factors = [
      velocity_check(order, history),
      address_mismatch_score(order),
      payment_pattern_analysis(history),
      order_anomaly_detection(order, history)
    ]
    
    Enum.sum(factors) / length(factors)
  end
end
```

## Monitoring and observability integration

The implementation includes **comprehensive monitoring** for business metrics and system health:

```elixir
defmodule Accountex.Sales.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def metrics do
    [
      # Business metrics
      counter("sales_order.created.count"),
      distribution("sales_order.total_value", unit: :currency),
      summary("sales_order.fulfillment_time", unit: :millisecond),
      
      # Performance metrics
      distribution("sales_order.command.duration", 
        tags: [:command_type], 
        unit: :millisecond),
      counter("sales_order.payment.failure.count", 
        tags: [:failure_reason]),
      
      # System health
      last_value("sales_order.event_store.lag", unit: :event),
      gauge("sales_order.active_sagas.count")
    ]
  end

  def handle_event([:sales_order, :created], measurements, metadata, _config) do
    # Track business KPIs
    track_conversion_funnel(metadata.order)
    update_revenue_metrics(measurements.total_value)
    
    # Alert on anomalies
    if measurements.total_value > threshold_for_tier(metadata.customer_tier) do
      notify_sales_team(metadata.order)
    end
  end
end
```

## Conclusion

Part 6 of the Accountex Sales Order business logic establishes **sophisticated order processing capabilities** through event-sourced payment handling, agentic fulfillment coordination, and intelligent cross-module integration. The implementation leverages Commanded's event sourcing for complete audit trails, Jido's autonomous agents for adaptive workflows, and Ash's declarative patterns for maintainable business rules. The architecture ensures resilient operation through graceful degradation when modules are unavailable, while Phoenix.PubSub enables efficient internal communication without external dependencies. This design provides the foundation for complex enterprise scenarios while maintaining the flexibility to evolve with changing business requirements.

# Accountex Sales Orders Logic - Part 7

## Freight calculation and shipping management

This seventh part of the Accountex Sales Orders logic focuses on freight calculation, overshipping functionality, module setup parameters, and cross-module integration patterns. The design follows event-sourced architecture principles using Ash framework, Commanded, and Jido for agentic capabilities.

## Module Setup Parameters

### Core Configuration Domain

The Sales Order module configuration is managed as an event-sourced aggregate that tracks all configuration changes over time, enabling rollback capabilities and configuration auditing.

```elixir
defmodule Accountex.Sales.Setup do
  use Ash.Resource
  use AshCommanded

  attributes do
    uuid_primary_key :id
    attribute :organization_id, :uuid, allow_nil?: false
    
    # Order Numbering Configuration
    attribute :order_number_format, :map do
      default %{
        prefix: "SO",
        separator: "-",
        sequence_length: 6,
        reset_period: :yearly,
        include_year: true
      }
    end
    
    # Freight Configuration
    attribute :freight_settings, :map do
      default %{
        calculation_method: :multi_tier, # :flat_rate, :weight_based, :zone_based, :carrier_integrated
        default_carrier: nil,
        auto_calculate: true,
        recalculation_triggers: [:quantity_change, :address_change, :item_change],
        freight_allocation_method: :proportional_by_value,
        minimum_freight_charge: Decimal.new("0"),
        freight_tax_code: nil
      }
    end
    
    # Overshipping Configuration
    attribute :overshipping_settings, :map do
      default %{
        enabled: false,
        default_tolerance_percentage: Decimal.new("0"),
        require_approval: true,
        approval_threshold_percentage: Decimal.new("10"),
        customer_override_allowed: true,
        product_override_allowed: true
      }
    end
    
    # Integration Settings
    attribute :integration_settings, :map do
      default %{
        inventory_check_enabled: true,
        credit_check_enabled: true,
        credit_check_timing: :on_booking, # :on_entry, :on_approval, :on_shipping
        real_time_inventory_update: true,
        gl_posting_timing: :on_invoice,
        ar_auto_invoice: true
      }
    end
    
    # Approval Workflow
    attribute :approval_settings, :map do
      default %{
        approval_required: false,
        approval_threshold: Decimal.new("10000"),
        approval_matrix: [],
        auto_approve_returning_customers: false,
        escalation_hours: 24
      }
    end
    
    attribute :active, :boolean, default: true
    timestamps()
  end

  commanded do
    commands do
      command :update_freight_configuration do
        fields [:organization_id, :freight_settings]
        action :update_freight_config
      end
      
      command :update_overshipping_rules do
        fields [:organization_id, :overshipping_settings]
        action :update_overshipping
      end
    end
    
    events do
      event :freight_configuration_updated do
        fields [:organization_id, :freight_settings, :updated_by, :updated_at]
      end
      
      event :overshipping_rules_updated do
        fields [:organization_id, :overshipping_settings, :updated_by, :updated_at]
      end
    end
  end
end
```

## Freight Calculation Business Logic

### Freight Calculator Domain Service

The freight calculation engine supports multiple calculation methods and real-time carrier integration while maintaining event-driven recalculation capabilities.

```elixir
defmodule Accountex.Sales.FreightCalculator do
  use Ash.Resource.Change
  alias Accountex.Sales.{Setup, SalesOrder}
  alias Accountex.Shipping.CarrierService
  
  def calculate_freight(order, opts \\ []) do
    with {:ok, config} <- get_freight_configuration(order.organization_id),
         {:ok, calculation_method} <- determine_calculation_method(order, config),
         {:ok, base_freight} <- calculate_base_freight(order, calculation_method),
         {:ok, adjusted_freight} <- apply_freight_adjustments(base_freight, order, config) do
      
      freight_breakdown = %{
        base_amount: base_freight,
        fuel_surcharge: calculate_fuel_surcharge(base_freight, config),
        residential_delivery: calculate_residential_charge(order, config),
        special_handling: calculate_special_handling(order),
        total: adjusted_freight
      }
      
      {:ok, freight_breakdown}
    end
  end
  
  defp calculate_base_freight(order, :weight_based) do
    total_weight = Enum.reduce(order.line_items, Decimal.new("0"), fn item, acc ->
      item_weight = get_item_weight(item.product_id) |> Decimal.mult(item.quantity)
      Decimal.add(acc, item_weight)
    end)
    
    freight = apply_weight_breaks(total_weight, order.shipping_zone)
    {:ok, freight}
  end
  
  defp calculate_base_freight(order, :zone_based) do
    with {:ok, origin_zone} <- get_warehouse_zone(order.warehouse_id),
         {:ok, destination_zone} <- get_customer_zone(order.shipping_address),
         {:ok, rate_table} <- get_zone_rate_table(origin_zone, destination_zone) do
      
      freight = calculate_from_zone_matrix(rate_table, order)
      {:ok, freight}
    end
  end
  
  defp calculate_base_freight(order, :carrier_integrated) do
    with {:ok, carrier} <- get_carrier_service(order.ship_via),
         {:ok, rates} <- CarrierService.get_real_time_rates(carrier, order) do
      
      selected_rate = select_optimal_rate(rates, order.service_level)
      {:ok, selected_rate.amount}
    end
  end
  
  defp calculate_base_freight(order, :multi_tier) do
    # Combine multiple calculation methods
    calculations = [
      calculate_base_freight(order, :weight_based),
      calculate_base_freight(order, :zone_based),
      calculate_minimum_charge(order)
    ]
    
    freight = calculations
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, amount} -> amount end)
      |> Enum.max()
    
    {:ok, freight}
  end
  
  # Freight allocation across line items
  def allocate_freight_to_lines(order, total_freight, method \\ :proportional_by_value) do
    case method do
      :proportional_by_value ->
        allocate_by_value(order.line_items, total_freight)
      
      :proportional_by_weight ->
        allocate_by_weight(order.line_items, total_freight)
      
      :proportional_by_quantity ->
        allocate_by_quantity(order.line_items, total_freight)
      
      :equal_distribution ->
        allocate_equally(order.line_items, total_freight)
    end
  end
  
  defp allocate_by_value(line_items, total_freight) do
    order_total = Enum.reduce(line_items, Decimal.new("0"), fn item, acc ->
      Decimal.add(acc, item.extended_amount)
    end)
    
    Enum.map(line_items, fn item ->
      item_percentage = Decimal.div(item.extended_amount, order_total)
      freight_amount = Decimal.mult(total_freight, item_percentage)
      
      Map.put(item, :allocated_freight, freight_amount)
    end)
  end
end
```

### Freight Recalculation Rules

The system implements event-driven freight recalculation with configurable triggers and intelligent batching for performance optimization.

```elixir
defmodule Accountex.Sales.FreightRecalculation do
  use Commanded.Event.Handler,
    application: Accountex.Application,
    name: "freight_recalculation_handler"
    
  alias Accountex.Sales.{FreightCalculator, SalesOrder}
  
  # Define recalculation triggers
  def handle(%OrderLineQuantityChanged{} = event, metadata) do
    if should_recalculate?(:quantity_change, event.order_id) do
      schedule_freight_recalculation(event.order_id, :quantity_change)
    end
    :ok
  end
  
  def handle(%ShippingAddressChanged{} = event, metadata) do
    if should_recalculate?(:address_change, event.order_id) do
      schedule_freight_recalculation(event.order_id, :address_change)
    end
    :ok
  end
  
  def handle(%LineItemAdded{} = event, metadata) do
    if should_recalculate?(:item_change, event.order_id) do
      schedule_freight_recalculation(event.order_id, :item_addition)
    end
    :ok
  end
  
  def handle(%ShipViaChanged{} = event, metadata) do
    # Ship via changes always trigger immediate recalculation
    immediate_freight_recalculation(event.order_id, :carrier_change)
    :ok
  end
  
  defp should_recalculate?(trigger_type, order_id) do
    with {:ok, order} <- SalesOrder.get(order_id),
         {:ok, config} <- get_freight_configuration(order.organization_id) do
      
      trigger_type in config.freight_settings.recalculation_triggers &&
        order.status in [:draft, :pending_approval, :approved] &&
        not order.freight_locked
    else
      _ -> false
    end
  end
  
  defp schedule_freight_recalculation(order_id, reason) do
    # Batch recalculations for performance
    Accountex.Jobs.FreightRecalculation.schedule(
      order_id: order_id,
      reason: reason,
      delay_seconds: 5  # Small delay to batch rapid changes
    )
  end
  
  defp immediate_freight_recalculation(order_id, reason) do
    Task.async(fn ->
      recalculate_and_update_freight(order_id, reason)
    end)
  end
  
  def recalculate_and_update_freight(order_id, reason) do
    with {:ok, order} <- SalesOrder.get(order_id),
         {:ok, new_freight} <- FreightCalculator.calculate_freight(order),
         {:ok, _} <- update_order_freight(order, new_freight, reason) do
      
      # Publish freight recalculated event
      publish_event(%FreightRecalculated{
        order_id: order_id,
        old_amount: order.freight_amount,
        new_amount: new_freight.total,
        reason: reason,
        calculated_at: DateTime.utc_now()
      })
    end
  end
end
```

## Overshipping Functionality

### Overshipping Domain Logic

The overshipping system manages quantity tolerances, approval workflows, and inventory impacts while maintaining full audit trails through event sourcing.

```elixir
defmodule Accountex.Sales.Overshipping do
  use Ash.Resource
  use AshCommanded
  
  attributes do
    uuid_primary_key :id
    attribute :order_id, :uuid, allow_nil?: false
    attribute :line_item_id, :uuid, allow_nil?: false
    
    attribute :ordered_quantity, :decimal, allow_nil?: false
    attribute :requested_ship_quantity, :decimal, allow_nil?: false
    attribute :overship_quantity, :decimal, allow_nil?: false
    attribute :overship_percentage, :decimal, allow_nil?: false
    
    attribute :tolerance_source, :atom do
      constraints [one_of: [:system_default, :customer_specific, :product_specific, :order_override]]
    end
    
    attribute :tolerance_limit, :decimal, allow_nil?: false
    attribute :within_tolerance, :boolean, allow_nil?: false
    
    attribute :approval_status, :atom do
      constraints [one_of: [:not_required, :pending, :approved, :rejected]]
      default :not_required
    end
    
    attribute :approved_by, :uuid
    attribute :approved_at, :utc_datetime
    attribute :rejection_reason, :string
    
    attribute :business_justification, :string
    timestamps()
  end
  
  commanded do
    commands do
      command :request_overship do
        fields [:order_id, :line_item_id, :requested_ship_quantity, :business_justification]
        action :create_overship_request
      end
      
      command :approve_overship do
        fields [:id, :approved_by]
        action :approve
      end
      
      command :reject_overship do
        fields [:id, :rejected_by, :rejection_reason]
        action :reject
      end
    end
    
    events do
      event :overship_requested do
        fields [:order_id, :line_item_id, :overship_quantity, :overship_percentage, :within_tolerance]
      end
      
      event :overship_approved do
        fields [:id, :order_id, :approved_by, :approved_at]
      end
      
      event :overship_executed do
        fields [:order_id, :line_item_id, :actual_shipped_quantity, :overship_quantity]
      end
    end
  end
  
  calculations do
    calculate :can_overship, :boolean do
      calculation fn record, _context ->
        record.within_tolerance || record.approval_status == :approved
      end
    end
  end
end
```

### Overshipping Business Rules Engine

```elixir
defmodule Accountex.Sales.OvershippingRules do
  alias Accountex.Sales.{Overshipping, Setup}
  alias Accountex.Customers.Customer
  alias Accountex.Inventory.Product
  
  def evaluate_overship_request(order, line_item, requested_quantity) do
    with {:ok, tolerance} <- get_applicable_tolerance(order, line_item),
         {:ok, overship_data} <- calculate_overship(line_item, requested_quantity),
         {:ok, validation} <- validate_overship(overship_data, tolerance),
         {:ok, inventory_check} <- check_inventory_availability(line_item, requested_quantity) do
      
      %{
        can_overship: validation.within_tolerance || validation.pre_approved,
        requires_approval: !validation.within_tolerance && !validation.pre_approved,
        overship_quantity: overship_data.overship_quantity,
        overship_percentage: overship_data.overship_percentage,
        tolerance_limit: tolerance,
        inventory_available: inventory_check.available,
        business_impact: calculate_business_impact(order, overship_data)
      }
    end
  end
  
  defp get_applicable_tolerance(order, line_item) do
    # Priority: Order Override > Product Specific > Customer Specific > System Default
    cond do
      order.overship_tolerance_override != nil ->
        {:ok, order.overship_tolerance_override}
      
      product_tolerance = get_product_tolerance(line_item.product_id) ->
        {:ok, product_tolerance}
      
      customer_tolerance = get_customer_tolerance(order.customer_id) ->
        {:ok, customer_tolerance}
      
      true ->
        get_system_default_tolerance(order.organization_id)
    end
  end
  
  defp calculate_overship(line_item, requested_quantity) do
    ordered = line_item.quantity
    overship_qty = Decimal.sub(requested_quantity, ordered)
    overship_pct = Decimal.div(overship_qty, ordered) |> Decimal.mult(100)
    
    {:ok, %{
      ordered_quantity: ordered,
      requested_quantity: requested_quantity,
      overship_quantity: overship_qty,
      overship_percentage: overship_pct
    }}
  end
  
  defp validate_overship(overship_data, tolerance_limit) do
    within_tolerance = Decimal.compare(overship_data.overship_percentage, tolerance_limit) != :gt
    
    {:ok, %{
      within_tolerance: within_tolerance,
      pre_approved: check_pre_approval(overship_data),
      validation_messages: generate_validation_messages(overship_data, tolerance_limit)
    }}
  end
  
  defp calculate_business_impact(order, overship_data) do
    %{
      revenue_impact: calculate_revenue_impact(order, overship_data),
      margin_impact: calculate_margin_impact(order, overship_data),
      inventory_impact: calculate_inventory_impact(overship_data),
      customer_satisfaction: estimate_satisfaction_impact(order, overship_data)
    }
  end
  
  # Backorder vs Overshipping Decision Logic
  def determine_fulfillment_strategy(order, line_item, available_quantity) do
    ordered_qty = line_item.quantity
    
    cond do
      # Sufficient inventory - ship as ordered
      Decimal.compare(available_quantity, ordered_qty) == :eq ->
        {:ship_complete, ordered_qty}
      
      # Excess inventory available - evaluate overshipping
      Decimal.compare(available_quantity, ordered_qty) == :gt ->
        evaluate_overship_opportunity(order, line_item, available_quantity)
      
      # Insufficient inventory - evaluate partial shipping
      Decimal.compare(available_quantity, ordered_qty) == :lt ->
        evaluate_partial_shipment(order, line_item, available_quantity)
    end
  end
  
  defp evaluate_overship_opportunity(order, line_item, available_quantity) do
    with {:ok, customer_prefs} <- get_customer_preferences(order.customer_id),
         {:ok, product_attrs} <- get_product_attributes(line_item.product_id) do
      
      cond do
        # Customer accepts overshipping for efficiency
        customer_prefs.accept_overshipping && product_attrs.overshippable ->
          propose_overship(order, line_item, available_quantity)
        
        # Product has limited shelf life - prefer overshipping
        product_attrs.perishable && within_expiration_window?(line_item) ->
          propose_overship(order, line_item, available_quantity)
        
        # Standard case - ship exact quantity
        true ->
          {:ship_exact, line_item.quantity}
      end
    end
  end
end
```

## Integration with Other Modules

### Inventory Integration

Real-time inventory synchronization with sophisticated reservation management and multi-warehouse coordination.

```elixir
defmodule Accountex.Sales.Integrations.InventoryBridge do
  use Commanded.Event.Handler,
    application: Accountex.Application,
    name: "sales_inventory_integration"
    
  alias Accountex.Inventory
  
  def handle(%OrderConfirmed{} = event, _metadata) do
    # Create inventory reservations
    Enum.each(event.line_items, fn item ->
      Inventory.reserve_stock(%{
        order_id: event.order_id,
        product_id: item.product_id,
        quantity: item.quantity,
        warehouse_id: item.warehouse_id,
        reservation_type: :sales_order,
        expires_at: calculate_reservation_expiry(event)
      })
    end)
    :ok
  end
  
  def handle(%OrderShipped{} = event, _metadata) do
    # Convert reservations to actual inventory depletion
    Enum.each(event.shipped_items, fn item ->
      Inventory.deplete_stock(%{
        order_id: event.order_id,
        product_id: item.product_id,
        quantity: item.shipped_quantity,
        warehouse_id: item.warehouse_id,
        lot_number: item.lot_number,
        serial_numbers: item.serial_numbers,
        transaction_type: :sales_shipment
      })
    end)
    :ok
  end
  
  def handle(%OvershipExecuted{} = event, _metadata) do
    # Handle overshipped inventory adjustments
    Inventory.adjust_for_overship(%{
      order_id: event.order_id,
      product_id: event.product_id,
      overship_quantity: event.overship_quantity,
      adjustment_reason: :authorized_overship
    })
    :ok
  end
  
  def handle(%OrderCancelled{} = event, _metadata) do
    # Release all inventory reservations
    Inventory.release_reservations(%{
      order_id: event.order_id,
      release_reason: :order_cancelled
    })
    :ok
  end
end
```

### Accounts Receivable Integration

Automated invoice generation with sophisticated revenue recognition and credit management.

```elixir
defmodule Accountex.Sales.Integrations.ARBridge do
  use Commanded.Event.Handler,
    application: Accountex.Application,
    name: "sales_ar_integration"
    
  alias Accountex.AR
  
  def handle(%OrderInvoiced{} = event, _metadata) do
    # Create AR invoice including freight and overshipped quantities
    invoice_data = %{
      customer_id: event.customer_id,
      order_id: event.order_id,
      invoice_date: event.invoice_date,
      due_date: calculate_due_date(event),
      
      line_items: Enum.map(event.line_items, fn item ->
        %{
          product_id: item.product_id,
          quantity: item.invoiced_quantity,  # Includes overshipped qty
          unit_price: item.unit_price,
          extended_amount: item.extended_amount,
          allocated_freight: item.allocated_freight,
          tax_amount: item.tax_amount
        }
      end),
      
      freight_amount: event.freight_amount,
      tax_amount: event.total_tax,
      total_amount: event.invoice_total,
      
      payment_terms: event.payment_terms,
      currency: event.currency
    }
    
    AR.create_invoice(invoice_data)
    :ok
  end
  
  def handle(%FreightRecalculated{} = event, _metadata) do
    # Update AR invoice if already created
    if invoice_exists?(event.order_id) do
      AR.adjust_invoice_freight(%{
        order_id: event.order_id,
        new_freight_amount: event.new_amount,
        adjustment_reason: event.reason
      })
    end
    :ok
  end
  
  def handle(%OrderCreditCheckRequested{} = event, _metadata) do
    # Perform credit check through AR module
    Task.async(fn ->
      credit_result = AR.check_customer_credit(%{
        customer_id: event.customer_id,
        requested_amount: event.order_total,
        include_pending_orders: true
      })
      
      publish_event(%CreditCheckCompleted{
        order_id: event.order_id,
        customer_id: event.customer_id,
        credit_status: credit_result.status,
        available_credit: credit_result.available_credit
      })
    end)
    :ok
  end
end
```

### General Ledger Integration

Comprehensive GL posting with proper account determination and multi-dimensional accounting support.

```elixir
defmodule Accountex.Sales.Integrations.GLBridge do
  use Commanded.Event.Handler,
    application: Accountex.Application,
    name: "sales_gl_integration"
    
  alias Accountex.GL
  
  def handle(%OrderShipped{} = event, _metadata) do
    # Create GL entries for COGS and inventory relief
    journal_entries = Enum.flat_map(event.shipped_items, fn item ->
      [
        %{
          account_code: determine_cogs_account(item),
          debit: item.unit_cost |> Decimal.mult(item.shipped_quantity),
          credit: nil,
          dimension_1: event.department,
          dimension_2: event.project_code
        },
        %{
          account_code: determine_inventory_account(item),
          debit: nil,
          credit: item.unit_cost |> Decimal.mult(item.shipped_quantity),
          dimension_1: event.department,
          dimension_2: event.project_code
        }
      ]
    end)
    
    GL.create_journal_entry(%{
      reference_type: "SALES_SHIPMENT",
      reference_id: event.order_id,
      entries: journal_entries,
      posting_date: event.shipped_date
    })
    :ok
  end
  
  def handle(%OrderInvoiced{} = event, _metadata) do
    # Create revenue recognition entries
    revenue_entries = build_revenue_entries(event)
    freight_entries = build_freight_entries(event)
    tax_entries = build_tax_entries(event)
    
    all_entries = revenue_entries ++ freight_entries ++ tax_entries
    
    GL.create_journal_entry(%{
      reference_type: "SALES_INVOICE",
      reference_id: event.order_id,
      entries: all_entries,
      posting_date: event.invoice_date
    })
    :ok
  end
  
  defp build_freight_entries(event) do
    if Decimal.compare(event.freight_amount, Decimal.new("0")) == :gt do
      [
        %{
          account_code: get_freight_revenue_account(),
          debit: nil,
          credit: event.freight_amount,
          description: "Freight revenue"
        },
        %{
          account_code: get_freight_expense_account(),
          debit: event.freight_cost || event.freight_amount,
          credit: nil,
          description: "Freight expense"
        }
      ]
    else
      []
    end
  end
end
```

## Event-Driven Interactions

### Sales Order Event Choreography

The system implements sophisticated event choreography patterns for complex multi-step processes.

```elixir
defmodule Accountex.Sales.EventChoreography do
  use Commanded.ProcessManagers.ProcessManager,
    application: Accountex.Application,
    name: "sales_order_process_manager"
    
  @derive Jason.Encoder
  defstruct [
    :order_id,
    :customer_id,
    :status,
    :credit_check_status,
    :inventory_check_status,
    :freight_calculation_status,
    :approval_status,
    :steps_completed,
    :errors
  ]
  
  def interested?(%OrderCreated{order_id: order_id}), do: {:start, order_id}
  def interested?(%CreditCheckCompleted{order_id: order_id}), do: {:continue, order_id}
  def interested?(%InventoryChecked{order_id: order_id}), do: {:continue, order_id}
  def interested?(%FreightCalculated{order_id: order_id}), do: {:continue, order_id}
  def interested?(%OrderApproved{order_id: order_id}), do: {:continue, order_id}
  def interested?(%OrderRejected{order_id: order_id}), do: {:stop, order_id}
  def interested?(%OrderFulfilled{order_id: order_id}), do: {:stop, order_id}
  def interested?(_event), do @ false
  
  def handle(%OrderCreated{} = event, %__MODULE__{} = pm) do
    pm = %{pm | 
      order_id: event.order_id,
      customer_id: event.customer_id,
      status: :processing,
      steps_completed: []
    }
    
    # Trigger parallel processes
    commands = [
      %CheckCustomerCredit{
        order_id: event.order_id,
        customer_id: event.customer_id,
        order_total: event.total_amount
      },
      %CheckInventoryAvailability{
        order_id: event.order_id,
        line_items: event.line_items
      },
      %CalculateFreight{
        order_id: event.order_id,
        shipping_address: event.shipping_address,
        line_items: event.line_items
      }
    ]
    
    {commands, pm}
  end
  
  def handle(%CreditCheckCompleted{} = event, %__MODULE__{} = pm) do
    pm = %{pm | 
      credit_check_status: event.credit_status,
      steps_completed: [:credit_check | pm.steps_completed]
    }
    
    maybe_complete_order_processing(pm)
  end
  
  def handle(%InventoryChecked{} = event, %__MODULE__{} = pm) do
    pm = %{pm | 
      inventory_check_status: event.availability_status,
      steps_completed: [:inventory_check | pm.steps_completed]
    }
    
    maybe_complete_order_processing(pm)
  end
  
  def handle(%FreightCalculated{} = event, %__MODULE__{} = pm) do
    pm = %{pm |
      freight_calculation_status: :completed,
      steps_completed: [:freight_calculation | pm.steps_completed]
    }
    
    maybe_complete_order_processing(pm)
  end
  
  defp maybe_complete_order_processing(pm) do
    required_steps = [:credit_check, :inventory_check, :freight_calculation]
    
    if all_steps_completed?(pm, required_steps) do
      if can_auto_approve?(pm) do
        {[%ApproveOrder{order_id: pm.order_id, approved_by: :system}], pm}
      else
        {[%RequestOrderApproval{order_id: pm.order_id}], pm}
      end
    else
      {[], pm}
    end
  end
  
  defp all_steps_completed?(pm, required_steps) do
    Enum.all?(required_steps, &(&1 in pm.steps_completed))
  end
  
  defp can_auto_approve?(pm) do
    pm.credit_check_status == :approved &&
      pm.inventory_check_status == :available &&
      pm.freight_calculation_status == :completed
  end
end
```

### Freight-Specific Event Handlers

```elixir
defmodule Accountex.Sales.FreightEventHandlers do
  use Jido.Agent,
    name: "freight_optimization_agent",
    description: "Optimizes freight calculations and carrier selection"
    
  def handle_carrier_rate_update(event) do
    affected_orders = find_orders_using_carrier(event.carrier_id)
    
    Enum.each(affected_orders, fn order ->
      if should_recalculate_for_rate_change?(order, event) do
        schedule_freight_optimization(order.id)
      end
    end)
  end
  
  def handle_fuel_surcharge_update(event) do
    # Batch process all pending orders for freight adjustment
    pending_orders = get_pending_orders_with_freight()
    
    batch_updates = Enum.map(pending_orders, fn order ->
      %RecalculateFreightCommand{
        order_id: order.id,
        reason: :fuel_surcharge_change,
        effective_date: event.effective_date
      }
    end)
    
    dispatch_batch(batch_updates)
  end
  
  def optimize_multi_order_shipment(customer_id, date_range) do
    orders = get_customer_orders(customer_id, date_range)
    
    optimization_result = run_optimization_algorithm(orders)
    
    if optimization_result.savings > threshold() do
      propose_consolidated_shipment(orders, optimization_result)
    end
  end
  
  defp run_optimization_algorithm(orders) do
    # Complex optimization logic for freight consolidation
    total_individual = calculate_individual_freight(orders)
    total_consolidated = calculate_consolidated_freight(orders)
    
    %{
      savings: Decimal.sub(total_individual, total_consolidated),
      consolidated_freight: total_consolidated,
      consolidation_strategy: determine_best_strategy(orders)
    }
  end
end
```

## Summary

This seventh part of the Accountex Sales Orders logic provides comprehensive business logic for freight calculation, overshipping functionality, module setup parameters, and cross-module integrations. The design leverages event-sourcing through AshCommanded for complete audit trails, uses Jido agents for intelligent automation, and implements sophisticated business rules while maintaining modularity and scalability.

  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "arden claude hook Stop"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "arden claude hook SubagentStop"
          }
        ]
      }
    ]
  },
  "feedbackSurveyState": {
    "lastShownTime": 1754078347577
  }
Key features include multi-method freight calculation with real-time carrier integration, configurable overshipping tolerances with approval workflows, comprehensive module setup parameters for organizational flexibility, and event-driven integration patterns that ensure data consistency across the ERP system. The architecture supports both synchronous and asynchronous processing patterns, enabling efficient handling of high-volume transactions while maintaining system responsiveness.
