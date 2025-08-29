# Sales Order Business Logic Document - Part 3

## Advanced Features and Master Data Management

### Sales Territory Management

```elixir
defmodule Accountex.SalesOrders.Commands.DefineSalesTerritory do
  @moduledoc """
  Command to define a new sales territory
  
  ## Business Rules
  - BR-SO-128: Territory codes must be unique
  - BR-SO-129: Geographic boundaries must not overlap with same type
  - BR-SO-130: Parent territory must exist if specified
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
```

### Customer Product Cross-References

```elixir
defmodule Accountex.SalesOrders.Commands.CreateCustomerProductReference do
  @moduledoc """
  Command to create customer-specific product reference
  
  ## Business Rules
  - BR-SO-131: Customer and product must exist
  - Customer part number unique per customer
  - BR-SO-132: Custom pricing requires approval if below minimum margin
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
```

### Sales-Specific Pricing Rules

```elixir
defmodule Accountex.SalesOrders.Commands.CreateSalesPricingRule do
  @moduledoc """
  Command to create sales-specific pricing rule
  
  ## Business Rules
  - Priority determines rule evaluation order
  - BR-SO-133: Date ranges must not overlap for same scope
  - BR-SO-134: Discount cannot exceed maximum allowed percentage
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
```

### Advanced Billing and Kit Customization

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

defmodule CreateAdvanceBill do
  defstruct [
    :order_id,
    :billing_lines,
    :payment_terms,
    :due_date,
    :early_payment_discount
  ]
end

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
```

### Kit Customization Logic

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

## Read Models and Projections

### Order Analytics Projection

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

### Quote Conversion Tracking

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
```

## Security and Compliance

### Authorization Policies

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

### Audit Requirements

**BR-SO-035:** All order modifications logged with user and timestamp
**BR-SO-036:** Price override justifications required
**BR-SO-037:** Credit limit override tracking
**BR-SO-038:** Cancellation reason codes mandatory
**BR-SO-039:** Document version history maintained

## Performance Optimizations

### Caching Strategies

- Customer data caching with TTL
- Price list caching by effective date
- Inventory availability caching with invalidation
- Tax rate caching by jurisdiction
- Credit limit caching with real-time updates

### Event Store Optimization

- Snapshot creation every 100 events
- Event archival after 90 days
- Projection rebuild capabilities
- Event replay performance tuning
- Read model denormalization

## Error Handling and Recovery

### Compensation Strategies

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

### Retry Policies

- Transient failure retry with exponential backoff
- Maximum retry attempts configurable by operation
- Dead letter queue for failed operations
- Manual intervention workflows
- Automated escalation procedures

## Integration Points

### Event Store Configuration

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

### Command Router Configuration

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

## Data Quality and Validation

### Master Data Validation

```elixir
defmodule Accountex.Sales.Rules.MasterRuleRegistry do
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
      ]
    }
  end
end
```

### Data Quality Management

```elixir
defmodule Accountex.Sales.DataQuality do
  def validate_system_consistency do
    %{
      customer_references: validate_customer_references(),
      product_references: validate_product_references(),
      pricing_consistency: validate_pricing_consistency(),
      territory_assignments: validate_territory_assignments(),
      commission_calculations: validate_commission_calculations()
    }
  end
  
  def repair_data_inconsistencies(validation_results) do
    validation_results
    |> Enum.filter(fn {_check, result} -> result != :ok end)
    |> Enum.map(fn {check, errors} ->
      attempt_automatic_repair(check, errors)
    end)
  end
end
```

## Reporting and Analytics

### Sales Performance Reports

```elixir
defmodule Accountex.Reports.SalesPerformance do
  def generate_sales_summary(date_range) do
    %{
      total_orders: count_orders(date_range),
      total_revenue: sum_order_values(date_range),
      average_order_value: calculate_aov(date_range),
      conversion_rate: calculate_conversion_rate(date_range),
      top_products: get_top_products(date_range),
      top_customers: get_top_customers(date_range),
      territory_performance: analyze_territories(date_range)
    }
  end
  
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
end
```

### Import Analysis Reports

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

## Monitoring and Analytics

### Key Performance Indicators

- Order cycle time
- Fulfillment accuracy rate
- Order value trends
- Cancellation reasons analysis
- Credit hold impact metrics

### Event Stream Analytics

- Real-time order velocity monitoring
- Inventory allocation success rates
- Payment processing metrics
- System performance monitoring
- Business event correlation

## Integration Architecture

The Sales Orders module integrates with other Accountex modules through well-defined event streams and API boundaries:

### Module Integration Patterns

#### Sales Order to Accounts Receivable

**Events Published:**
- `InvoiceGenerated` - AR invoice created from SO
- `PaymentApplied` - Customer payment received
- `CreditMemoIssued` - Credit adjustment processed
- `IntegrationError` - Posting failure occurred

#### Sales Order to Inventory Management

**Events Published:**
- `InventoryAllocated` - Stock reserved for order
- `InventoryShipped` - Stock removed from inventory
- `BackorderCreated` - Insufficient stock available
- `InventoryReplenishmentTriggered` - Reorder point reached

#### Sales Order to General Ledger

**Events Published:**
- Revenue recognition entries
- COGS posting
- Tax liability recording
- Deferred revenue management
- Journal entry creation

### CQRS Implementation

**Command Processing:**
- Processes business commands
- Validates business rules
- Generates domain events
- Updates aggregate state
- Returns command result

**Query Processing:**
- Consumes domain events
- Updates denormalized views
- Maintains query optimization
- Handles eventual consistency
- Provides fast query response

## Conclusion

This comprehensive business logic document provides the foundation for implementing a robust, scalable Sales Order management system within the Accountex platform using event-sourced architecture and modern integration patterns. The system supports complex manufacturing scenarios including multi-level BOMs, sophisticated costing methods, quality control integration, and advanced scheduling while maintaining flexibility for customization and scalability.

Key architectural features include:

- **Event Sourcing** for complete audit trails and temporal queries
- **CQRS** for optimized read/write operations
- **Modular Design** enabling independent deployment and scaling
- **Comprehensive Validation** ensuring data quality and business rule compliance
- **Advanced Integration** patterns for seamless module interaction
- **Performance Optimization** through caching and query optimization
- **Error Recovery** with compensation patterns and retry logic

---

*This completes Part 3 of 3. See [sales_orders_logic_part1.md](./sales_orders_logic_part1.md) for Core Domain Concepts and [sales_orders_logic_part2.md](./sales_orders_logic_part2.md) for Shipping and Cancellation Processes.*