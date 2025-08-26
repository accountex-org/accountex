# Inventory Control Business Logic Specification

## Executive Summary

This document defines the comprehensive business logic for the Accountex Inventory Control module, designed as an event-sourced system using Commanded/AshCommanded architecture. The specification covers all core inventory management capabilities including item management, warehouse operations, costing methods, and integration patterns with other Accountex modules.

## Module Context and Dependencies

### Core Objectives
The Inventory Control module manages the complete lifecycle of inventory items from receipt through consumption, maintaining accurate quantity and valuation records while supporting multiple warehouse locations, lot/serial tracking, and sophisticated costing methods.

### Module Dependencies
- **Required**: General Ledger (for financial postings)
- **Optional**: Sales Order Processing, Purchase Orders, Manufacturing
- **Conditional**: Accounts Receivable (if internal billing enabled), Accounts Payable (for landed costs)

### Integration Architecture
The module operates on an event-driven architecture where all state changes emit domain events that other modules can consume. The system maintains eventual consistency across module boundaries through process managers and saga orchestration.

## Domain Model and Aggregates

### Core Aggregates

#### InventoryItem Aggregate
**State Components:**
```
{
  item_id: string,
  sku: string,
  description: string,
  item_type: enum[stock, non_stock, service, kit],
  status: enum[active, inactive, discontinued],
  costing_method: enum[fifo, lifo, average, specific, standard],
  standard_cost: decimal,
  reorder_point: decimal,
  reorder_quantity: decimal,
  safety_stock: decimal,
  serial_controlled: boolean,
  lot_controlled: boolean,
  kit_components: list[component],
  specifications: map[string, any]
}
```

#### WarehouseLocation Aggregate
**State Components:**
```
{
  location_id: string,
  warehouse_code: string,
  bin_structure: {zones, aisles, bays, levels, positions},
  capacity_constraints: {weight, volume, quantity},
  bin_rankings: map[bin_id, rank],
  default_bins: {receive, ship, putaway, pick, qc},
  item_locations: map[item_id, list[bin_location]]
}
```

#### InventoryBalance Aggregate
**State Components:**
```
{
  balance_id: {item_id, location_id},
  quantity_on_hand: decimal,
  quantity_allocated: decimal,
  quantity_available: decimal,
  quantity_in_transit: decimal,
  cost_layers: list[{date, quantity, unit_cost}],
  lot_balances: map[lot_number, quantity],
  serial_numbers: list[serial_number]
}
```

## Business Rules and Validation

### Item Management Rules

#### BR-INV-001: Item Type Validation
- Stock items must have valid warehouse assignments
- Non-stock items cannot have quantity on hand
- Service items cannot be received into inventory
- Kit items must have at least one component defined

#### BR-INV-002: Unit of Measure Consistency
- Primary UOM cannot be changed after transactions exist
- Conversion factors must maintain mathematical consistency
- Inter-class conversions require explicit approval

#### BR-INV-003: Status Transition Rules
- Active → Inactive: Allowed only when quantity_on_hand = 0
- Inactive → Discontinued: Requires management approval
- Discontinued → Active: Creates new revision with audit trail

### Serial/Lot Number Control

#### BR-INV-004: Serial Number Uniqueness
- Serial numbers must be globally unique within item
- Format validation: `^[A-Z]{2}[0-9]{10}$` (configurable)
- Once assigned, serial numbers cannot be reused

#### BR-INV-005: Lot Expiration Management
- Expired lots automatically quarantined on expiration_date + buffer_days
- FEFO (First Expired First Out) picking when lot_controlled = true
- Retest intervals trigger quality hold status

#### BR-INV-006: Traceability Requirements
- All serial/lot controlled items maintain complete genealogy
- Forward tracing: raw_material → work_in_process → finished_good → customer
- Backward tracing: customer_complaint → finished_good → raw_material_batch

### Warehouse Operations

#### BR-INV-007: Bin Capacity Constraints
```
validation: current_quantity + incoming_quantity <= bin_capacity
exception: allow_overflow = true AND overflow_percentage <= 10%
```

#### BR-INV-008: Transfer Authorization
- Inter-warehouse transfers > $10,000 require approval
- Cross-company transfers require inter-company agreement
- In-transit insurance required for transfers > $50,000

#### BR-INV-009: Negative Inventory Prevention
```
rule: quantity_on_hand - quantity_requested >= 0
exception: allow_negative_inventory = true AND user_role IN [inventory_manager, administrator]
timing: validation occurs at transaction_commit, not command_validation
```

### Physical Count Rules

#### BR-INV-010: Count Freeze Logic
- No transactions allowed during active count for counted bins
- Pending transactions queued until count completion
- Emergency overrides require dual authorization

#### BR-INV-011: Variance Tolerances
```
A-items: tolerance = 0.5% OR $100, whichever is less
B-items: tolerance = 2% OR $500, whichever is less
C-items: tolerance = 5% OR $1000, whichever is less
```

#### BR-INV-012: Recount Triggers
- Automatic recount if variance > tolerance
- Blind recount by different counter required
- Third count by supervisor if variance persists

## Calculations and Formulas

### Costing Method Calculations

#### FIFO Cost Calculation
```
function calculate_fifo_cost(quantity_issued):
  remaining = quantity_issued
  total_cost = 0
  
  for layer in cost_layers.order_by(receipt_date):
    if layer.quantity >= remaining:
      total_cost += remaining * layer.unit_cost
      layer.quantity -= remaining
      break
    else:
      total_cost += layer.quantity * layer.unit_cost
      remaining -= layer.quantity
      layer.quantity = 0
      
  return total_cost / quantity_issued
```

#### Average Cost Recalculation
```
new_average_cost = 
  (current_quantity * current_average + receipt_quantity * receipt_cost) /
  (current_quantity + receipt_quantity)
```

#### Standard Cost Variance
```
purchase_price_variance = (actual_cost - standard_cost) * quantity_received
usage_variance = (actual_quantity - standard_quantity) * standard_cost
total_variance = purchase_price_variance + usage_variance
```

### Reorder Point Calculations

#### Basic Reorder Point
```
reorder_point = (average_daily_usage * lead_time_days) + safety_stock
```

#### Safety Stock with Demand Variability
```
safety_stock = service_level_z_score * 
               standard_deviation_demand * 
               sqrt(lead_time_days)
```

#### Economic Order Quantity
```
EOQ = sqrt((2 * annual_demand * ordering_cost) / holding_cost)
```

### Multi-level Pricing

#### Price Determination Hierarchy
```
function determine_price(customer, item, quantity, date):
  if contract_price_exists(customer, item, date):
    return contract_price
  elif promotional_price_active(item, date):
    return promotional_price
  elif quantity >= volume_break_threshold:
    return volume_price
  elif customer_tier_price_exists(customer.tier, item):
    return tier_price
  else:
    return base_price
```

#### Margin Validation
```
minimum_margin = (selling_price - landed_cost) / selling_price
if minimum_margin < required_margin_percentage:
  raise PricingApprovalRequired
```

## State Transitions

### Item Lifecycle States
```
Created → Active → Inactive → Discontinued → Archived

Transitions:
- Created→Active: When first receipt recorded
- Active→Inactive: When manually deactivated OR quantity_on_hand = 0 for X days
- Inactive→Discontinued: Management decision
- Discontinued→Archived: After retention_period expires
```

### Inventory Transaction States
```
Pending → Validated → Posted → Completed

Transitions:
- Pending→Validated: All business rules pass
- Validated→Posted: Financial entries created
- Posted→Completed: All downstream processes complete
```

### Transfer States
```
Draft → Submitted → Approved → In_Transit → Received → Completed

Transitions:
- Draft→Submitted: Required fields complete
- Submitted→Approved: Authorization obtained
- Approved→In_Transit: Shipment initiated
- In_Transit→Received: Goods receipt confirmed
- Received→Completed: Variances resolved, GL posted
```

### Physical Count States
```
Scheduled → Active → Counted → Validated → Adjusted → Closed

Transitions:
- Scheduled→Active: Count date reached
- Active→Counted: All items scanned
- Counted→Validated: Variances reviewed
- Validated→Adjusted: Adjustments posted
- Adjusted→Closed: Final reports generated
```

## Commands and Events

### Core Commands

#### Item Management Commands
```elixir
CreateItem(%{
  sku: string,
  description: string,
  item_type: atom,
  primary_uom: string,
  costing_method: atom
})

UpdateItemSpecifications(%{
  item_id: uuid,
  specifications: map
})

ActivateItem(%{item_id: uuid})
DeactivateItem(%{item_id: uuid, reason: string})
```

#### Stock Movement Commands
```elixir
ReceiveStock(%{
  item_id: uuid,
  location_id: uuid,
  quantity: decimal,
  unit_cost: decimal,
  lot_number: string | nil,
  serial_numbers: list | nil
})

IssueStock(%{
  item_id: uuid,
  location_id: uuid,
  quantity: decimal,
  lot_number: string | nil,
  serial_numbers: list | nil
})

TransferStock(%{
  item_id: uuid,
  from_location_id: uuid,
  to_location_id: uuid,
  quantity: decimal,
  transfer_reason: string
})

AdjustStock(%{
  item_id: uuid,
  location_id: uuid,
  adjustment_quantity: decimal,
  adjustment_reason: string,
  adjustment_code: string
})
```

#### Count Commands
```elixir
InitiatePhysicalCount(%{
  location_id: uuid,
  count_type: atom,
  expected_items: list
})

RecordCountedQuantity(%{
  count_id: uuid,
  item_id: uuid,
  counted_quantity: decimal,
  counter_id: uuid
})

FinalizeCount(%{
  count_id: uuid,
  supervisor_id: uuid
})
```

### Domain Events

#### Item Events
```elixir
ItemCreated(%{
  item_id: uuid,
  sku: string,
  created_at: datetime,
  created_by: uuid
})

ItemSpecificationsUpdated(%{
  item_id: uuid,
  previous_specifications: map,
  new_specifications: map,
  updated_at: datetime
})

ItemStatusChanged(%{
  item_id: uuid,
  previous_status: atom,
  new_status: atom,
  change_reason: string
})
```

#### Inventory Movement Events
```elixir
StockReceived(%{
  transaction_id: uuid,
  item_id: uuid,
  location_id: uuid,
  quantity: decimal,
  unit_cost: decimal,
  total_cost: decimal,
  lot_number: string | nil,
  serial_numbers: list | nil,
  received_at: datetime
})

StockIssued(%{
  transaction_id: uuid,
  item_id: uuid,
  location_id: uuid,
  quantity: decimal,
  cost_of_goods_sold: decimal,
  lot_number: string | nil,
  serial_numbers: list | nil,
  issued_at: datetime
})

StockTransferred(%{
  transfer_id: uuid,
  item_id: uuid,
  from_location_id: uuid,
  to_location_id: uuid,
  quantity: decimal,
  transfer_cost: decimal,
  initiated_at: datetime
})

StockAdjusted(%{
  adjustment_id: uuid,
  item_id: uuid,
  location_id: uuid,
  previous_quantity: decimal,
  new_quantity: decimal,
  adjustment_value: decimal,
  reason_code: string,
  adjusted_at: datetime
})
```

#### Count Events
```elixir
PhysicalCountStarted(%{
  count_id: uuid,
  location_id: uuid,
  expected_items: list,
  freeze_timestamp: datetime
})

ItemCounted(%{
  count_id: uuid,
  item_id: uuid,
  system_quantity: decimal,
  counted_quantity: decimal,
  variance: decimal,
  counted_by: uuid
})

CountVarianceDetected(%{
  count_id: uuid,
  item_id: uuid,
  variance_quantity: decimal,
  variance_value: decimal,
  tolerance_exceeded: boolean
})

CountCompleted(%{
  count_id: uuid,
  total_variance_value: decimal,
  adjustment_entries: list,
  completed_at: datetime
})
```

## Process Managers and Sagas

### Transfer Process Manager
Orchestrates the complete transfer workflow including reservation at source, in-transit tracking, and receipt at destination.

```elixir
defmodule TransferProcessManager do
  # Triggered by TransferInitiated event
  def handle(%TransferInitiated{} = event, state) do
    commands = [
      %ReserveStockAtSource{
        item_id: event.item_id,
        location_id: event.from_location_id,
        quantity: event.quantity
      }
    ]
    {commands, %{state | status: :reserving}}
  end
  
  def handle(%StockReserved{} = event, state) do
    commands = [
      %CreateShipment{
        transfer_id: state.transfer_id,
        carrier: determine_carrier(state)
      }
    ]
    {commands, %{state | status: :shipping}}
  end
  
  def handle(%ShipmentReceived{} = event, state) do
    commands = [
      %ReceiveStockAtDestination{
        item_id: state.item_id,
        location_id: state.to_location_id,
        quantity: event.received_quantity
      },
      %ReleaseReservation{
        item_id: state.item_id,
        location_id: state.from_location_id,
        quantity: state.reserved_quantity
      }
    ]
    {commands, %{state | status: :completing}}
  end
end
```

### Count Reconciliation Saga
Handles the reconciliation of physical count variances including recount triggers and adjustment postings.

```elixir
defmodule CountReconciliationSaga do
  def handle(%CountVarianceDetected{tolerance_exceeded: true} = event) do
    %InitiateRecount{
      original_count_id: event.count_id,
      item_id: event.item_id,
      priority: :high
    }
  end
  
  def handle(%RecountCompleted{} = event) do
    if variance_persists?(event) do
      %RequestSupervisorApproval{
        count_id: event.count_id,
        variance_details: calculate_variance_details(event)
      }
    else
      %PostInventoryAdjustment{
        item_id: event.item_id,
        adjustment_quantity: event.final_variance,
        reason_code: "PHYS_COUNT"
      }
    end
  end
end
```

### Kit Assembly Process Manager
Coordinates the assembly of kit items including component availability checking and consumption.

```elixir
defmodule KitAssemblyProcessManager do
  def handle(%AssemblyRequested{} = event, state) do
    # Check component availability
    component_checks = Enum.map(event.kit_components, fn component ->
      %CheckComponentAvailability{
        item_id: component.item_id,
        required_quantity: component.quantity * event.kit_quantity
      }
    end)
    
    {component_checks, %{state | status: :checking_availability}}
  end
  
  def handle(%AllComponentsAvailable{} = event, state) do
    # Issue components and receive finished kit
    issue_commands = Enum.map(state.components, fn component ->
      %IssueComponent{
        item_id: component.item_id,
        quantity: component.required_quantity,
        kit_assembly_id: state.assembly_id
      }
    end)
    
    receive_command = %ReceiveAssembledKit{
      kit_item_id: state.kit_item_id,
      quantity: state.kit_quantity,
      assembly_cost: calculate_assembly_cost(state)
    }
    
    {issue_commands ++ [receive_command], %{state | status: :assembling}}
  end
end
```

## Read Models and Projections

### Current Stock Levels Projection
```elixir
defmodule CurrentStockProjection do
  def handle(%StockReceived{} = event) do
    update_stock_level(
      event.item_id,
      event.location_id,
      &(&1 + event.quantity)
    )
  end
  
  def handle(%StockIssued{} = event) do
    update_stock_level(
      event.item_id,
      event.location_id,
      &(&1 - event.quantity)
    )
  end
end
```

### Available to Promise (ATP) Projection
```elixir
defmodule ATPProjection do
  def calculate_atp(item_id, location_id, date) do
    on_hand = get_current_stock(item_id, location_id)
    allocated = get_allocated_quantity(item_id, location_id, date)
    in_transit = get_in_transit_quantity(item_id, location_id, date)
    
    on_hand + in_transit - allocated
  end
end
```

### Inventory Valuation Projection
```elixir
defmodule InventoryValuationProjection do
  def calculate_inventory_value(as_of_date) do
    query = """
      SELECT 
        i.item_id,
        i.description,
        SUM(b.quantity_on_hand) as total_quantity,
        CASE i.costing_method
          WHEN 'standard' THEN i.standard_cost
          WHEN 'average' THEN b.average_cost
          ELSE calculate_layered_cost(i.item_id, i.costing_method)
        END as unit_cost,
        SUM(b.quantity_on_hand * unit_cost) as total_value
      FROM items i
      JOIN inventory_balances b ON i.item_id = b.item_id
      WHERE b.as_of_date <= :as_of_date
      GROUP BY i.item_id
    """
  end
end
```

## Integration Points

### General Ledger Integration
All inventory transactions generate corresponding GL entries:
```
Receipt: 
  DR: Inventory Asset Account
  CR: Goods Received Not Invoiced

Issue:
  DR: Cost of Goods Sold
  CR: Inventory Asset Account

Adjustment (+):
  DR: Inventory Asset Account
  CR: Inventory Adjustment Account

Adjustment (-):
  DR: Inventory Adjustment Account
  CR: Inventory Asset Account
```

### Sales Order Integration
```elixir
def handle(%SalesOrderCreated{} = event) when is_module_available(:sales_orders) do
  Enum.map(event.line_items, fn item ->
    %AllocateInventory{
      item_id: item.item_id,
      quantity: item.quantity,
      order_id: event.order_id,
      required_date: event.ship_date
    }
  end)
end
```

### Purchase Order Integration
```elixir
def handle(%PurchaseOrderReceived{} = event) when is_module_available(:purchase_orders) do
  %ReceiveStock{
    item_id: event.item_id,
    quantity: event.received_quantity,
    unit_cost: event.unit_price + calculate_landed_cost(event),
    po_reference: event.po_number
  }
end
```

### Manufacturing Integration
```elixir
def handle(%WorkOrderCompleted{} = event) when is_module_available(:manufacturing) do
  # Issue components
  component_issues = Enum.map(event.components_consumed, fn component ->
    %IssueStock{
      item_id: component.item_id,
      quantity: component.quantity,
      work_order_id: event.work_order_id
    }
  end)
  
  # Receive finished goods
  receipt = %ReceiveStock{
    item_id: event.finished_item_id,
    quantity: event.quantity_produced,
    unit_cost: calculate_production_cost(event)
  }
  
  component_issues ++ [receipt]
end
```

## Error Handling and Recovery

### Validation Errors
```elixir
def execute(%InventoryItem{} = item, %IssueStock{quantity: qty}) 
  when qty > item.quantity_available do
  {:error, :insufficient_inventory, 
   %{available: item.quantity_available, requested: qty}}
end
```

### Compensation Logic
```elixir
def compensate(%TransferFailed{} = event) do
  [
    %ReverseStockReservation{
      item_id: event.item_id,
      location_id: event.from_location_id,
      quantity: event.quantity
    },
    %NotifyTransferFailure{
      transfer_id: event.transfer_id,
      reason: event.failure_reason
    }
  ]
end
```

### Idempotency Handling
```elixir
def execute(%InventoryItem{last_transaction_id: last_id} = item, 
           %{transaction_id: tx_id} = command) 
  when last_id == tx_id do
  # Command already processed, return empty events
  []
end
```

## Performance Considerations

### Aggregate Size Management
- Snapshot InventoryBalance aggregates monthly or after 1000 events
- Archive completed transfers after 90 days
- Partition cost layers by fiscal year

### Query Optimization
- Denormalize frequently accessed data in read models
- Cache ATP calculations with 5-minute TTL
- Pre-calculate ABC classifications daily

### Event Stream Management
- Compress events older than 1 year
- Archive events older than 7 years
- Maintain separate streams per warehouse for scalability

## Security and Compliance

### Authorization Rules
- Inventory adjustments > $1,000 require manager approval
- Cost method changes require CFO approval
- Physical count variances > 5% require investigation

### Audit Requirements
- All stock movements maintain complete audit trail
- User, timestamp, and reason code for every transaction
- Immutable event log for regulatory compliance

### Data Retention
- Transaction details: 7 years
- Lot/serial genealogy: Product lifetime + 2 years
- Physical count records: 3 years

## Migration and Compatibility

### Legacy System Integration
- Support batch imports of historical transactions
- Maintain backward compatibility with existing item codes
- Gradual migration path from document-based to event-sourced

### Data Migration Rules
- Opening balances loaded as initial StockReceived events
- Cost layers reconstructed from historical transactions
- Serial/lot numbers validated for uniqueness during import

This specification provides the complete business logic foundation for implementing the Accountex Inventory Control module with sophisticated functionality while maintaining system integrity and supporting seamless integration with other modules in the Accountex ecosystem.
