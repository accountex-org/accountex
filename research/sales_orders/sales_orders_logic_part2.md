# Sales Order Business Logic Document - Part 2

## 4. Shipping Sales Orders Process

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

### Shipping Business Rules

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
end
```

## 5. Canceling Open Orders Process

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

### Cancellation Business Rules

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

## 6. Approving Sales Quotes Process

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

### Quote Approval Business Rules

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

## 7. Creating Recurring Sales Orders Process

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

## 8. Creating Blanket Sales Orders Process

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

### Blanket Order Business Rules

```elixir
defmodule Accountex.Sales.Rules.BlanketOrderRules do
  def commitment_rules do
    %{
      minimum_commitment_percentage: 80, # BR-SO-072
      validity_period_max_days: 365, # BR-SO-073
      release_quantity_min_percentage: 5, # BR-SO-074
      release_quantity_max_percentage: 50, # BR-SO-075
      price_lock_guarantee: true # BR-SO-076
    }
  end

  def release_validation do
    %{
      require_delivery_date: true, # BR-SO-077
      validate_warehouse_capacity: true, # BR-SO-078
      consolidate_releases_same_day: true, # BR-SO-079
      notify_customer_of_release: true # BR-SO-080
    }
  end

  def expiration_handling do
    %{
      advance_notice_days: 30, # BR-SO-081
      auto_extend_option: true, # BR-SO-082
      partial_release_expiration_policy: :pro_rata, # BR-SO-083
      penalty_calculation_method: :percentage_based # BR-SO-084
    }
  end
end
```

## Process Managers and Integration

### Shipping Process Manager

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
```

### Error Handling and Compensation

```elixir
defmodule Accountex.Sales.ErrorHandling.CompensationActions do
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
end
```

### Integration Points

```elixir
defmodule Accountex.Sales.Integrations.SystemIntegrations do
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
end
```

---

*This is Part 2 of 3. See [sales_orders_logic_part1.md](./sales_orders_logic_part1.md) for Core Domain Concepts and [sales_orders_logic_part3.md](./sales_orders_logic_part3.md) for Advanced Features and Reporting.*