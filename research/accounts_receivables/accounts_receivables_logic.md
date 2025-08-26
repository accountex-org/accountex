# Accountex Accounts Receivables Business Logic Design

## Overview

The Accounts Receivables (AR) application is a pluggable module in the Accountex system that manages customer billing, collections, and credit management. It operates as an event-sourced application using Commanded and AshCommanded, communicating with other modules through events.

## Core Domain Concepts

### 1. Customer Account Management

#### Aggregates

- **CustomerAccount**: Manages customer profile, credit limits, and payment terms
- **CustomerAddress**: Handles multiple billing/shipping addresses per customer
- **CustomerActivity**: Tracks interactions and activities with customers

#### Commands

- `CreateCustomer`
- `UpdateCustomerProfile`
- `SetCreditLimit`
- `AssignPaymentTerms`
- `AddCustomerAddress`
- `RecordCustomerActivity`
- `ArchiveCustomer`

#### Events

- `CustomerCreated`
- `CustomerProfileUpdated`
- `CreditLimitSet`
- `PaymentTermsAssigned`
- `CustomerAddressAdded`
- `CustomerActivityRecorded`
- `CustomerArchived`

#### Business Rules

- Credit limit validation against outstanding balances and open orders
- Customer classification for pricing and discount tiers
- Territory and salesperson assignment rules
- Parent-subsidiary account relationships

### 2. Invoice Management

#### Aggregates

- **Invoice**: Core billing document
- **InvoiceLineItem**: Individual items on invoices
- **RecurringInvoiceTemplate**: Templates for automated invoice generation

#### Commands

- `CreateInvoice`
- `AmendInvoice`
- `VoidInvoice`
- `CopyInvoice`
- `GenerateInvoiceFromShipment`
- `CreateRecurringInvoiceTemplate`
- `GenerateRecurringInvoice`

#### Events

- `InvoiceCreated`
- `InvoiceAmended`
- `InvoiceVoided`
- `InvoiceCopied`
- `InvoiceGeneratedFromShipment`
- `RecurringInvoiceTemplateCreated`
- `RecurringInvoiceGenerated`

#### Business Rules

- Invoice numbering (system-generated or manual)
- Tax calculation based on shipping address
- Freight charge calculation by weight or fixed amount
- Discount application hierarchy
- Multi-warehouse support
- Inventory allocation and depletion
- Serialized/lot-controlled item tracking

### 3. Sales Returns Processing

#### Aggregates

- **SalesReturn**: Manages product returns and credit generation

#### Commands

- `CreateSalesReturnWithoutInvoice`
- `CreateSalesReturnWithInvoice`
- `AmendSalesReturn`
- `VoidSalesReturn`

#### Events

- `SalesReturnCreated`
- `SalesReturnAmended`
- `SalesReturnVoided`
- `InventoryRestocked`
- `OpenCreditGenerated`

#### Business Rules

- Return authorization validation
- Serialized/lot/kit item return tracking
- Inventory restocking rules
- Credit note generation
- Return bin assignment

### 4. Payment Processing

#### Aggregates

- **Payment**: Customer payment records
- **PaymentApplication**: Application of payments to invoices
- **OpenCredit**: Unapplied payment amounts

#### Commands

- `ApplyPayment`
- `ApplyOpenCredit`
- `PostPrepayment`
- `PostNonCustomerPayment`
- `VoidPayment`
- `VoidAppliedCredit`
- `ProcessElectronicPayment`

#### Events

- `PaymentApplied`
- `OpenCreditApplied`
- `PrepaymentPosted`
- `NonCustomerPaymentPosted`
- `PaymentVoided`
- `AppliedCreditVoided`
- `ElectronicPaymentProcessed`

#### Business Rules

- Payment method validation (cash, check, credit card, electronic)
- Auto-application logic based on invoice age
- Prompt payment discount calculation
- Payment to finance charge priority
- Multi-currency exchange rate handling
- Average payment days calculation

### 5. Finance Charges

n

#### Aggregates

- **FinanceCharge**: Late payment charges

#### Commands

- `ApplyFinanceChargeByInvoice`
- `ApplyFinanceChargeByStatement`
- `AdjustFinanceCharge`

#### Events

- `FinanceChargeApplied`
- `FinanceChargeAdjusted`

#### Business Rules

- Charge calculation methods (percentage or fixed)
- Minimum balance thresholds
- Charge period restrictions
- Compound interest on outstanding charges
- Customer and pay code eligibility

### 6. Credit Management

#### Aggregates

- **OpenCreditRefund**: Refund processing for credit balances

#### Commands

- `RefundOpenCreditByCheck`
- `RefundOpenCreditByCash`
- `RefundOpenCreditByCard`

#### Events

- `OpenCreditRefunded`
- `RefundCheckQueued`
- `CashRefundProcessed`
- `CardRefundProcessed`

#### Business Rules

- Refund authorization
- AP integration for check refunds
- Negative receipt generation

### 7. Bank Deposit Management

#### Aggregates

- **BankDeposit**: Groups receipts for deposit

#### Commands

- `RecordBankDeposit`
- `AmendBankDeposit`
- `VoidBankDeposit`
- `VerifyBankDeposit`

#### Events

- `BankDepositRecorded`
- `BankDepositAmended`
- `BankDepositVoided`
- `BankDepositVerified`

#### Business Rules

- Receipt grouping by bank and date
- Deposit slip generation
- Bank reconciliation markers

## Integration Points

### With Sales Order Module

- **Inbound Events**:
  - `ShipmentCompleted` → Trigger invoice generation
  - `SalesOrderCreated` → Update customer open orders
  - `SalesOrderCancelled` → Adjust credit availability

- **Outbound Events**:
  - `InvoiceGenerated` → Update SO fulfillment status
  - `CreditLimitExceeded` → Notify SO for order holds

### With Inventory Control Module

- **Inbound Events**:
  - `InventoryAvailable` → Enable invoice line items
  - `ItemPriceUpdated` → Reflect in pending invoices

- **Outbound Events**:
  - `InventoryConsumed` → Decrease on-hand quantities
  - `InventoryRestocked` → Process returns
  - `SerialNumbersAllocated` → Track serialized items

### With General Ledger Module

- **Outbound Events**:
  - `RevenueRecognized` → Post sales entries
  - `ReceivableCreated` → Update AR balance
  - `BadDebtWrittenOff` → Adjust expense accounts
  - `DiscountGranted` → Post discount entries
  - `TaxCollected` → Update tax liability

### With Accounts Payable Module

- **Outbound Events**:
  - `RefundCheckRequested` → Create AP invoice for refund

### With Bank Reconciliation Module

- **Outbound Events**:
  - `DepositRecorded` → Update bank balance
  - `ElectronicPaymentProcessed` → Record ACH transactions

## Process Workflows

### Invoice Creation Workflow

1. Validate customer credit status
2. Check inventory availability
3. Calculate pricing based on hierarchy:
   - Customer-specific pricing
   - Price code pricing
   - Special/promotional pricing
   - Standard pricing
4. Apply discounts
5. Calculate taxes
6. Generate invoice number
7. Emit `InvoiceCreated` event
8. Update customer balances
9. Decrease inventory

### Payment Application Workflow

1. Validate payment method
2. Record receipt
3. Apply to invoices (oldest first or by selection)
4. Calculate and apply discounts
5. Generate open credit if overpayment
6. Update customer aging
7. Emit payment events

### Finance Charge Workflow

1. Identify eligible past-due accounts
2. Calculate charges based on configuration
3. Create charge invoices or adjust existing
4. Update customer balances
5. Emit charge events

### Electronic Payment Workflow

1. Generate prenote files
2. Await bank confirmation
3. Activate customer for electronic payments
4. Process payment batches
5. Generate NACHA files
6. Record transactions

## Multi-Currency Support

### Exchange Rate Management

- Real-time rate updates
- Transaction-specific rate overrides
- Gain/loss calculation on payment
- Revaluation processing

### Currency-Specific Rules

- Bank account currency matching
- Customer currency preferences
- Multi-currency price lists
- Foreign currency statements

## Data Validation Rules

### Invoice Validation

- Customer exists and is active
- Invoice date within open periods
- Payment terms are valid
- Tax codes are applicable
- Inventory availability for stock items
- Serial/lot numbers are unique

### Payment Validation

- Payment amount is positive
- Bank account matches currency
- Credit card is not expired
- Check number format is valid
- Receipt date is valid

### Credit Management

- Credit limit enforcement
- Past-due balance restrictions
- Order hold triggers
- Collection status flags

## Period-End Processing

### Commands

- `CloseAccountingPeriod`
- `TransferToGeneralLedger`
- `PerformCurrencyRevaluation`
- `ArchiveHistoricalData`

### Events

- `PeriodClosed`
- `DataTransferredToGL`
- `CurrencyRevaluationCompleted`
- `HistoricalDataArchived`

### Business Rules

- Prevent posting to closed periods
- Ensure all transactions are posted
- Validate GL account mappings
- Generate period-end reports

## Reporting Requirements

### Operational Reports

- Invoice listings and summaries
- Payment/cash receipts journals
- Customer aging analysis
- Open credit reports
- Sales analysis by customer/item/salesperson

### Financial Reports

- AR status and balances
- Revenue recognition
- Tax liability
- Currency gain/loss
- Bad debt analysis

### Customer Communications

- Statements (balance forward/open item)
- Collection letters
- Payment receipts
- Credit memos

# Accounts Receivables Business Logic - Part 2

## 10. Invoice Import System

### 10.1 Import Configuration

#### Import Structure Definition

```elixir
defmodule AccountsReceivables.InvoiceImport.Structure do
  use Ash.Resource
  
  attributes do
    attribute :id, :uuid, primary_key?: true
    attribute :name, :string, allow_nil?: false
    attribute :active, :boolean, default: true
    
    # Header field mappings
    attribute :header_fields, {:array, :map} do
      # Required: customer_number, invoice_number (unless system-generated)
      # Optional: invoice_date, salesperson_id, warehouse_id, 
      #          ship_via, fob, freight_code, sales_tax_code,
      #          pay_code, bank_id, ordered_by, pay_reference,
      #          foreign_freight_amount, remarks, customer_po,
      #          foreign_tax_amounts
    end
    
    # Line item field mappings
    attribute :line_item_fields, {:array, :map} do
      # Required: customer_number, item_number,
      #          foreign_unit_price OR foreign_subtotal_amount
      # Optional: sequence, specification_codes, description,
      #          unit_of_measure, commission, discount_percent,
      #          ship_quantity, unit_cost, item_remarks
    end
    
    attribute :delimiter, :string, default: ","
    attribute :header_identifier, :string, default: "*"
    attribute :encoding, :string, default: "UTF-8"
  end
end
```

#### Import Validation Rules

```elixir
defmodule AccountsReceivables.InvoiceImport.Validator do
  use Ash.Resource
  
  actions do
    action :validate_file, :map do
      argument :file_path, :string, allow_nil?: false
      argument :structure, :map, allow_nil?: false
      
      run fn input, _context ->
        with {:ok, content} <- read_file(input.file_path),
             {:ok, parsed} <- parse_content(content, input.structure),
             {:ok, validated} <- validate_structure(parsed, input.structure),
             {:ok, checked} <- check_business_rules(validated) do
          {:ok, %{
            valid_invoices: checked.valid,
            invalid_invoices: checked.invalid,
            validation_errors: checked.errors
          }}
        end
      end
    end
  end
  
  defp validate_structure(parsed, structure) do
    # Validate required fields present
    # Validate data types
    # Validate field order matches structure definition
    # Validate header lines start with identifier
    # Validate at least one detail line per invoice
  end
  
  defp check_business_rules(data) do
    # Customer exists and is active
    # Invoice number unique (if not system-generated)
    # Items exist and are active
    # Sales tax code valid
    # Pay code valid
    # Warehouse valid
    # Credit limit checks
    # Pricing validation
  end
end
```

### 10.2 Import Processing

#### Import Transaction Handler

```elixir
defmodule AccountsReceivables.InvoiceImport.Processor do
  use Commanded.ProcessManager
  
  @derive Jason.Encoder
  defstruct [:import_id, :status, :file_path, :structure_id, 
             :total_invoices, :processed_count, :error_count]
  
  def interested?(%InvoiceImportStarted{import_id: import_id}), 
    do: {:start, import_id}
  def interested?(%InvoiceValidated{import_id: import_id}), 
    do: {:continue, import_id}
  def interested?(%InvoiceImported{import_id: import_id}), 
    do: {:continue, import_id}
  def interested?(%InvoiceImportCompleted{import_id: import_id}), 
    do: {:stop, import_id}
  def interested?(%InvoiceImportFailed{import_id: import_id}), 
    do: {:stop, import_id}
  def interested?(_event), do: false
  
  def handle(%{} = state, %InvoiceImportStarted{} = event) do
    %{state | 
      import_id: event.import_id,
      file_path: event.file_path,
      structure_id: event.structure_id,
      status: :validating,
      total_invoices: 0,
      processed_count: 0,
      error_count: 0}
  end
  
  def handle(%{} = state, %InvoiceValidated{} = event) do
    if length(event.valid_invoices) > 0 do
      commands = Enum.map(event.valid_invoices, fn invoice_data ->
        %CreateInvoiceFromImport{
          import_id: state.import_id,
          invoice_data: invoice_data
        }
      end)
      
      {commands, %{state | 
        status: :importing,
        total_invoices: length(event.valid_invoices)}}
    else
      {%CompleteInvoiceImport{
        import_id: state.import_id,
        status: :completed_with_errors,
        error_count: length(event.invalid_invoices)
      }, state}
    end
  end
  
  def handle(%{} = state, %InvoiceImported{}) do
    new_state = %{state | processed_count: state.processed_count + 1}
    
    if new_state.processed_count >= new_state.total_invoices do
      {%CompleteInvoiceImport{
        import_id: new_state.import_id,
        status: :completed,
        processed_count: new_state.processed_count,
        error_count: new_state.error_count
      }, new_state}
    else
      new_state
    end
  end
end
```

#### Import Field Mapping

```elixir
defmodule AccountsReceivables.InvoiceImport.FieldMapper do
  use Ash.Resource
  
  actions do
    action :map_header_fields, :map do
      argument :raw_data, :map, allow_nil?: false
      argument :field_mapping, :map, allow_nil?: false
      argument :defaults, :map
      
      run fn input, _context ->
        mapped = map_fields(input.raw_data, input.field_mapping)
        
        # Apply system defaults for missing optional fields
        with_defaults = apply_defaults(mapped, input.defaults)
        
        # Derive calculated fields
        with_calculated = calculate_derived_fields(with_defaults)
        
        {:ok, with_calculated}
      end
    end
    
    action :map_line_items, {:array, :map} do
      argument :raw_items, {:array, :map}, allow_nil?: false
      argument :field_mapping, :map, allow_nil?: false
      argument :header_context, :map
      
      run fn input, _context ->
        items = Enum.map(input.raw_items, fn raw_item ->
          mapped = map_fields(raw_item, input.field_mapping)
          
          # Calculate extended amounts
          with_amounts = calculate_line_amounts(mapped)
          
          # Apply header-level defaults
          apply_line_defaults(with_amounts, input.header_context)
        end)
        
        {:ok, items}
      end
    end
  end
  
  defp calculate_line_amounts(item) do
    cond do
      item[:foreign_unit_price] && item[:ship_quantity] ->
        Map.put(item, :foreign_subtotal_amount, 
                item.foreign_unit_price * item.ship_quantity)
      
      item[:foreign_subtotal_amount] && item[:ship_quantity] ->
        Map.put(item, :foreign_unit_price, 
                item.foreign_subtotal_amount / item.ship_quantity)
      
      true -> item
    end
  end
end
```

## 11. Recurring Invoice System

### 11.1 Recurring Invoice Templates

#### Template Management

```elixir
defmodule AccountsReceivables.RecurringInvoice.Template do
  use Ash.Resource
  
  attributes do
    attribute :id, :uuid, primary_key?: true
    attribute :template_number, :string, allow_nil?: false
    attribute :customer_id, :uuid, allow_nil?: false
    attribute :status, :atom, default: :active,
      constraints: [one_of: [:active, :inactive, :suspended]]
    
    # Recurrence settings
    attribute :recurring_cycle, :atom, allow_nil?: false,
      constraints: [one_of: [:weekly, :bimonthly, :monthly, 
                            :quarterly, :semi_annually, :annually]]
    attribute :number_of_cycles, :integer
    attribute :next_recurrence_date, :date, allow_nil?: false
    attribute :end_recurrence_date, :date
    attribute :last_recurrence_date, :date
    
    # Invoice details
    attribute :warehouse_id, :uuid
    attribute :ship_via, :string
    attribute :fob, :string
    attribute :customer_po_number, :string
    attribute :ordered_by, :string
    attribute :salesperson_id, :uuid
    attribute :remark_id, :uuid
    attribute :commission_plan_id, :uuid
    attribute :discount_percentage, :decimal
    attribute :fixed_price, :boolean, default: false
    
    # Line items stored as embedded data
    attribute :line_items, {:array, :map} do
      # Each item contains:
      # - item_id, description, quantity, unit_price, 
      # - discount_percentage, specifications
    end
    
    # Payment settings
    attribute :pay_code_id, :uuid
    attribute :bank_account_id, :uuid
    attribute :payment_reference, :string
    
    # Address overrides
    attribute :billing_address_override, :map
    attribute :shipping_address_override, :map
    attribute :sales_tax_code_id, :uuid
    
    # Generation tracking
    attribute :generation_count, :integer, default: 0
    attribute :last_generated_at, :utc_datetime_usec
    attribute :next_generation_at, :utc_datetime_usec
  end
  
  relationships do
    belongs_to :customer, AccountsReceivables.Customer
    has_many :generated_invoices, AccountsReceivables.Invoice,
      destination_attribute: :recurring_template_id
  end
  
  calculations do
    calculate :remaining_cycles, :integer do
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          if record.number_of_cycles do
            record.number_of_cycles - record.generation_count
          else
            nil  # Infinite cycles
          end
        end)
      end
    end
    
    calculate :is_due_for_generation, :boolean do
      calculation fn records, context ->
        today = context[:current_date] || Date.utc_today()
        Enum.map(records, fn record ->
          record.status == :active && 
          record.next_recurrence_date <= today &&
          (is_nil(record.end_recurrence_date) || 
           record.end_recurrence_date >= today)
        end)
      end
    end
  end
end
```

#### Recurring Invoice Generator

```elixir
defmodule AccountsReceivables.RecurringInvoice.Generator do
  use GenServer
  
  defmodule State do
    defstruct [:generation_date_range, :customer_range, :dry_run]
  end
  
  def generate_recurring_invoices(opts \\ []) do
    GenServer.call(__MODULE__, {:generate, opts})
  end
  
  def handle_call({:generate, opts}, _from, state) do
    date_range = opts[:date_range] || default_date_range()
    customer_ids = opts[:customer_ids] || :all
    dry_run = opts[:dry_run] || false
    
    # Find eligible templates
    templates = find_eligible_templates(date_range, customer_ids)
    
    # Generate invoices for each eligible template
    results = Enum.map(templates, fn template ->
      generate_for_template(template, date_range, dry_run)
    end)
    
    summary = summarize_generation(results)
    
    {:reply, {:ok, summary}, state}
  end
  
  defp generate_for_template(template, date_range, dry_run) do
    # Calculate how many invoices to generate within date range
    invoice_dates = calculate_invoice_dates(template, date_range)
    
    Enum.map(invoice_dates, fn invoice_date ->
      invoice_data = build_invoice_data(template, invoice_date)
      
      if dry_run do
        {:dry_run, invoice_data}
      else
        case create_invoice_from_template(invoice_data) do
          {:ok, invoice} ->
            update_template_tracking(template, invoice_date)
            {:created, invoice}
          {:error, reason} ->
            {:error, template.id, reason}
        end
      end
    end)
  end
  
  defp calculate_invoice_dates(template, {start_date, end_date}) do
    Stream.iterate(template.next_recurrence_date, fn date ->
      advance_date(date, template.recurring_cycle)
    end)
    |> Stream.take_while(fn date -> 
      date >= start_date && date <= end_date &&
      (is_nil(template.end_recurrence_date) || date <= template.end_recurrence_date)
    end)
    |> Enum.to_list()
  end
  
  defp advance_date(date, :weekly), do: Date.add(date, 7)
  defp advance_date(date, :bimonthly), do: Date.add(date, 14)
  defp advance_date(date, :monthly), do: shift_months(date, 1)
  defp advance_date(date, :quarterly), do: shift_months(date, 3)
  defp advance_date(date, :semi_annually), do: shift_months(date, 6)
  defp advance_date(date, :annually), do: shift_months(date, 12)
  
  defp build_invoice_data(template, invoice_date) do
    %{
      customer_id: template.customer_id,
      invoice_date: invoice_date,
      recurring_template_id: template.id,
      warehouse_id: template.warehouse_id,
      ship_via: template.ship_via,
      fob: template.fob,
      customer_po_number: template.customer_po_number,
      line_items: if(template.fixed_price,
        do: template.line_items,
        else: reprice_line_items(template.line_items)
      ),
      payment_settings: %{
        pay_code_id: template.pay_code_id,
        bank_account_id: template.bank_account_id,
        payment_reference: template.payment_reference
      }
    }
  end
end
```

### 11.2 Recurring Invoice Processing

#### Amendment Handler

```elixir
defmodule AccountsReceivables.RecurringInvoice.AmendmentHandler do
  use Ash.Resource
  
  actions do
    update :amend_template do
      argument :amendments, :map, allow_nil?: false
      
      change fn changeset, _context ->
        amendments = changeset.arguments.amendments
        
        changeset
        |> validate_amendment_rules(amendments)
        |> apply_amendments(amendments)
        |> recalculate_schedule()
      end
    end
    
    update :suspend_template do
      change set_attribute(:status, :suspended)
      change set_attribute(:suspension_date, &DateTime.utc_now/0)
    end
    
    update :reactivate_template do
      argument :new_start_date, :date
      
      change fn changeset, _context ->
        changeset
        |> change_attribute(:status, :active)
        |> change_attribute(:next_recurrence_date, 
                           changeset.arguments.new_start_date)
        |> recalculate_end_date()
      end
    end
    
    destroy :void_template do
      change fn changeset, _context ->
        # Check if any invoices have been generated
        if changeset.data.generation_count > 0 do
          add_error(changeset, :base, 
                   "Cannot void template with generated invoices")
        else
          changeset
        end
      end
    end
  end
  
  defp validate_amendment_rules(changeset, amendments) do
    # Cannot change customer
    # Cannot change currency
    # Cannot reduce number of cycles below already generated
    # Must maintain pricing consistency if fixed_price is true
    changeset
  end
  
  defp recalculate_schedule(changeset) do
    if changed?(changeset, :recurring_cycle) || 
       changed?(changeset, :number_of_cycles) do
      changeset
      |> recalculate_end_date()
      |> validate_schedule_consistency()
    else
      changeset
    end
  end
end
```

## 12. Bank Deposit Transaction System

### 12.1 Deposit Recording

#### Bank Deposit Structure

```elixir
defmodule AccountsReceivables.BankDeposit do
  use Ash.Resource
  
  attributes do
    attribute :id, :uuid, primary_key?: true
    attribute :deposit_number, :string, allow_nil?: false
    attribute :bank_account_id, :uuid, allow_nil?: false
    attribute :deposit_date, :date, allow_nil?: false
    attribute :description, :string
    
    # Registration (from deposit slip)
    attribute :registered_receipt_count, :integer, allow_nil?: false
    attribute :registered_amount, :decimal, allow_nil?: false
    
    # Recording (from system selection)
    attribute :recorded_receipt_count, :integer, default: 0
    attribute :recorded_amount, :decimal, default: Decimal.new(0)
    
    # Verification
    attribute :verified, :boolean, default: false
    attribute :verification_date, :date
    attribute :verified_by, :uuid
    
    # Electronic payment specific
    attribute :is_electronic, :boolean, default: false
    attribute :effective_date, :date
    attribute :ach_batch_id, :string
    
    # Status tracking
    attribute :status, :atom, default: :draft,
      constraints: [one_of: [:draft, :recorded, :verified, :reconciled]]
    attribute :out_of_balance, :boolean, default: false
    attribute :balance_difference, :decimal
  end
  
  relationships do
    belongs_to :bank_account, AccountsReceivables.BankAccount
    has_many :deposit_items, AccountsReceivables.BankDepositItem
    has_many :receipts, AccountsReceivables.Receipt,
      through: [:deposit_items, :receipt]
    has_many :refunds, AccountsReceivables.Refund,
      through: [:deposit_items, :refund]
  end
  
  calculations do
    calculate :is_balanced, :boolean do
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          record.registered_receipt_count == record.recorded_receipt_count &&
          Decimal.equal?(record.registered_amount, record.recorded_amount)
        end)
      end
    end
  end
end
```

#### Deposit Item Selection

```elixir
defmodule AccountsReceivables.BankDeposit.Selector do
  use Ash.Resource
  
  actions do
    read :available_for_deposit do
      argument :bank_account_id, :uuid, allow_nil?: false
      argument :date_range, :map, allow_nil?: false
      argument :pay_codes, {:array, :uuid}
      argument :deposit_type, :atom, default: :standard,
        constraints: [one_of: [:standard, :direct_deposit]]
      
      filter expr(
        bank_account_id == ^arg(:bank_account_id) and
        is_nil(deposit_id) and
        transaction_date >= ^arg(:date_range).start_date and
        transaction_date <= ^arg(:date_range).end_date
      )
      
      prepare fn query, _context ->
        query
        |> filter_by_pay_codes()
        |> filter_by_deposit_type()
        |> exclude_voided_unless_in_range()
      end
    end
    
    action :auto_select_by_pay_code do
      argument :pay_code_id, :uuid, allow_nil?: false
      argument :receipt_date, :date, allow_nil?: false
      
      run fn input, _context ->
        # Find all receipts with matching pay code and date
        matching_receipts = find_matching_receipts(
          input.pay_code_id, 
          input.receipt_date
        )
        
        # Group by pay code for optimal deposit batching
        grouped = group_by_pay_code(matching_receipts)
        
        # Return selection with totals
        {:ok, %{
          selected_items: grouped,
          total_count: length(matching_receipts),
          total_amount: sum_amounts(matching_receipts),
          suggested_description: generate_description(grouped)
        }}
      end
    end
  end
  
  defp filter_by_deposit_type(query, :direct_deposit) do
    query
    |> join(:inner, [r], pc in assoc(r, :pay_code))
    |> where([r, pc], pc.is_ach == true)
    |> where([r], r.prenote_status == :confirmed)
  end
  
  defp filter_by_deposit_type(query, :standard) do
    query
    |> join(:inner, [r], pc in assoc(r, :pay_code))
    |> where([r, pc], pc.is_ach == false or is_nil(pc.is_ach))
  end
end
```

### 12.2 Deposit Verification

#### Verification Processor

```elixir
defmodule AccountsReceivables.BankDeposit.Verifier do
  use Commanded.ProcessManager
  
  @derive Jason.Encoder
  defstruct [:deposit_id, :bank_account_id, :verification_status,
             :items_to_verify, :verified_items, :verification_errors]
  
  def interested?(%DepositRecorded{deposit_id: deposit_id}), 
    do: {:start, deposit_id}
  def interested?(%DepositItemVerified{deposit_id: deposit_id}), 
    do: {:continue, deposit_id}
  def interested?(%DepositVerificationCompleted{deposit_id: deposit_id}), 
    do: {:stop, deposit_id}
  def interested?(_event), do: false
  
  def handle(%{} = state, %DepositRecorded{} = event) do
    %{state | 
      deposit_id: event.deposit_id,
      bank_account_id: event.bank_account_id,
      verification_status: :pending,
      items_to_verify: event.deposit_items,
      verified_items: [],
      verification_errors: []}
  end
  
  def handle(%{} = state, %DepositItemVerified{} = event) do
    new_state = %{state | 
      verified_items: [event.item_id | state.verified_items]}
    
    if all_items_verified?(new_state) do
      {%CompleteDepositVerification{
        deposit_id: state.deposit_id,
        verification_date: Date.utc_today(),
        verified_by: event.verified_by
      }, new_state}
    else
      new_state
    end
  end
  
  defp all_items_verified?(state) do
    MapSet.equal?(
      MapSet.new(state.items_to_verify),
      MapSet.new(state.verified_items)
    )
  end
end
```

#### Verification Workflow

```elixir
defmodule AccountsReceivables.BankDeposit.VerificationWorkflow do
  use Ash.Resource
  
  actions do
    update :mark_verified do
      argument :verification_date, :date, default: &Date.utc_today/0
      argument :verified_by, :uuid, allow_nil?: false
      
      validate fn changeset, _context ->
        # Cannot verify if not balanced
        unless changeset.data.is_balanced do
          add_error(changeset, :base, 
                   "Cannot verify out-of-balance deposit")
        end
        
        # Cannot verify if already verified
        if changeset.data.verified do
          add_error(changeset, :base, "Deposit already verified")
        end
        
        changeset
      end
      
      change set_attribute(:verified, true)
      change set_attribute(:verification_date, arg(:verification_date))
      change set_attribute(:verified_by, arg(:verified_by))
      change set_attribute(:status, :verified)
    end
    
    update :unmark_verified do
      validate fn changeset, _context ->
        # Cannot unverify if reconciled
        if changeset.data.status == :reconciled do
          add_error(changeset, :base, 
                   "Cannot unverify reconciled deposit")
        end
        
        changeset
      end
      
      change set_attribute(:verified, false)
      change set_attribute(:verification_date, nil)
      change set_attribute(:verified_by, nil)
      change set_attribute(:status, :recorded)
    end
  end
end
```

### 12.3 Bank Deposit Amendment

#### Amendment Rules

```elixir
defmodule AccountsReceivables.BankDeposit.Amendment do
  use Ash.Resource
  
  actions do
    update :amend_deposit do
      accept [:deposit_date, :description, :registered_receipt_count,
              :registered_amount]
      
      argument :add_items, {:array, :uuid}, default: []
      argument :remove_items, {:array, :uuid}, default: []
      
      validate fn changeset, _context ->
        # Cannot amend verified deposits
        if changeset.data.verified do
          add_error(changeset, :base, 
                   "Cannot amend verified deposit. Unverify first.")
        end
        
        # Cannot amend reconciled deposits
        if changeset.data.status == :reconciled do
          add_error(changeset, :base, "Cannot amend reconciled deposit")
        end
        
        changeset
      end
      
      change fn changeset, context ->
        changeset
        |> process_item_additions(context.arguments.add_items)
        |> process_item_removals(context.arguments.remove_items)
        |> recalculate_totals()
        |> check_balance()
      end
    end
    
    destroy :void_deposit do
      validate fn changeset, _context ->
        # Cannot void verified deposit
        if changeset.data.verified do
          add_error(changeset, :base, 
                   "Cannot void verified deposit. Unverify first.")
        end
        
        # Cannot void reconciled deposit
        if changeset.data.status == :reconciled do
          add_error(changeset, :base, "Cannot void reconciled deposit")
        end
        
        changeset
      end
      
      change fn changeset, _context ->
        # Release all deposit items
        release_deposit_items(changeset.data)
        changeset
      end
    end
  end
  
  defp recalculate_totals(changeset) do
    items = get_current_items(changeset)
    
    recorded_count = length(items)
    recorded_amount = Enum.reduce(items, Decimal.new(0), fn item, acc ->
      Decimal.add(acc, item.amount)
    end)
    
    changeset
    |> change_attribute(:recorded_receipt_count, recorded_count)
    |> change_attribute(:recorded_amount, recorded_amount)
  end
  
  defp check_balance(changeset) do
    registered_amount = get_field(changeset, :registered_amount)
    recorded_amount = get_field(changeset, :recorded_amount)
    
    if Decimal.equal?(registered_amount, recorded_amount) do
      changeset
      |> change_attribute(:out_of_balance, false)
      |> change_attribute(:balance_difference, Decimal.new(0))
    else
      difference = Decimal.sub(registered_amount, recorded_amount)
      
      changeset
      |> change_attribute(:out_of_balance, true)
      |> change_attribute(:balance_difference, difference)
    end
  end
end
```

## Integration Events

### Import Events

```elixir
defmodule AccountsReceivables.Events.ImportEvents do
  defmodule InvoiceImportStarted do
    @derive Jason.Encoder
    defstruct [:import_id, :file_path, :structure_id, :user_id, :timestamp]
  end
  
  defmodule InvoiceValidated do
    @derive Jason.Encoder
    defstruct [:import_id, :valid_invoices, :invalid_invoices, :errors]
  end
  
  defmodule InvoiceImported do
    @derive Jason.Encoder
    defstruct [:import_id, :invoice_id, :invoice_number, :customer_id]
  end
  
  defmodule InvoiceImportCompleted do
    @derive Jason.Encoder
    defstruct [:import_id, :status, :processed_count, :error_count, :summary]
  end
  
  defmodule InvoiceImportFailed do
    @derive Jason.Encoder
    defstruct [:import_id, :reason, :errors]
  end
end
```

### Recurring Invoice Events

```elixir
defmodule AccountsReceivables.Events.RecurringEvents do
  defmodule RecurringTemplateCreated do
    @derive Jason.Encoder
    defstruct [:template_id, :customer_id, :recurring_cycle, 
               :start_date, :end_date]
  end
  
  defmodule RecurringInvoiceGenerated do
    @derive Jason.Encoder
    defstruct [:template_id, :invoice_id, :invoice_date, :cycle_number]
  end
  
  defmodule RecurringGenerationCompleted do
    @derive Jason.Encoder
    defstruct [:generation_id, :templates_processed, :invoices_created, 
               :errors]
  end
  
  defmodule RecurringTemplateAmended do
    @derive Jason.Encoder
    defstruct [:template_id, :changes, :amended_by, :timestamp]
  end
  
  defmodule RecurringTemplateSuspended do
    @derive Jason.Encoder
    defstruct [:template_id, :suspension_date, :reason]
  end
end
```

### Bank Deposit Events

```elixir
defmodule AccountsReceivables.Events.DepositEvents do
  defmodule DepositRecorded do
    @derive Jason.Encoder
    defstruct [:deposit_id, :bank_account_id, :deposit_date, 
               :deposit_items, :total_amount]
  end
  
  defmodule DepositItemAdded do
    @derive Jason.Encoder
    defstruct [:deposit_id, :item_id, :item_type, :amount]
  end
  
  defmodule DepositVerified do
    @derive Jason.Encoder
    defstruct [:deposit_id, :verification_date, :verified_by]
  end
  
  defmodule DepositUnverified do
    @derive Jason.Encoder
    defstruct [:deposit_id, :unverified_by, :reason]
  end
  
  defmodule DepositAmended do
    @derive Jason.Encoder
    defstruct [:deposit_id, :changes, :new_balance_status]
  end
  
  defmodule DepositVoided do
    @derive Jason.Encoder
    defstruct [:deposit_id, :void_date, :voided_by, :released_items]
  end
end
```

## Error Handling

### Import Error Handler

```elixir
defmodule AccountsReceivables.InvoiceImport.ErrorHandler do
  use GenServer
  
  def handle_import_error(import_id, error) do
    case error do
      {:validation_error, details} ->
        log_validation_error(import_id, details)
        notify_user_validation_failed(import_id, details)
        
      {:business_rule_violation, rule, data} ->
        log_business_rule_violation(import_id, rule, data)
        add_to_invalid_invoices(import_id, data, rule)
        
      {:system_error, reason} ->
        log_system_error(import_id, reason)
        mark_import_failed(import_id, reason)
        schedule_retry(import_id)
    end
  end
  
  defp add_to_invalid_invoices(import_id, invoice_data, violation) do
    # Store invalid invoice with reason for review
    %{
      import_id: import_id,
      invoice_data: invoice_data,
      rejection_reason: format_violation(violation),
      can_retry: determine_retry_eligibility(violation)
    }
    |> store_invalid_invoice()
  end
end
```

### Recurring Invoice Error Recovery

```elixir
defmodule AccountsReceivables.RecurringInvoice.ErrorRecovery do
  use GenServer
  
  def handle_generation_failure(template_id, error) do
    case categorize_error(error) do
      :temporary ->
        # Retry in next generation cycle
        log_temporary_failure(template_id, error)
        
      :configuration ->
        # Suspend template and notify
        suspend_template(template_id)
        notify_configuration_error(template_id, error)
        
      :business_rule ->
        # Skip this cycle, continue with next
        log_skipped_cycle(template_id, error)
        advance_to_next_cycle(template_id)
        
      :critical ->
        # Suspend all generation for customer
        suspend_customer_templates(template_id)
        escalate_critical_error(template_id, error)
    end
  end
end
```

## Performance Optimizations

### Batch Processing

```elixir
defmodule AccountsReceivables.BatchProcessor do
  use GenServer
  
  def process_import_batch(invoices, batch_size \\ 100) do
    invoices
    |> Stream.chunk_every(batch_size)
    |> Task.async_stream(&process_batch/1, 
                        max_concurrency: 4,
                        timeout: 30_000)
    |> Enum.reduce({[], []}, fn
      {:ok, {:ok, results}}, {success, errors} ->
        {success ++ results, errors}
      {:ok, {:error, reason}}, {success, errors} ->
        {success, errors ++ [reason]}
      {:exit, reason}, {success, errors} ->
        {success, errors ++ [{:timeout, reason}]}
    end)
  end
  
  def generate_recurring_batch(templates, date_range) do
    # Process templates in parallel by customer
    templates
    |> Enum.group_by(& &1.customer_id)
    |> Task.async_stream(fn {customer_id, customer_templates} ->
      generate_for_customer(customer_id, customer_templates, date_range)
    end, max_concurrency: System.schedulers_online())
    |> collect_results()
  end
end
```

### Caching Strategy

```elixir
defmodule AccountsReceivables.Cache do
  use Nebulex.Cache,
    otp_app: :accounts_receivables,
    adapter: Nebulex.Adapters.Local
  
  def cache_import_structure(structure_id, structure_data) do
    put({"import_structure", structure_id}, structure_data,
        ttl: :timer.hours(24))
  end
  
  def cache_recurring_template(template_id, template_data) do
    put({"recurring_template", template_id}, template_data,
        ttl: :timer.hours(1))
  end
  
  def cache_deposit_items(bank_account_id, date_range, items) do
    key = {"deposit_items", bank_account_id, date_range}
    put(key, items, ttl: :timer.minutes(15))
  end
end
```

## Security and Audit

### Access Control

- Function-level permissions
- Customer-level restrictions
- Amount thresholds
- Void/amendment authorization

### Audit Trail

- All events are immutable
- User tracking on all commands
- Timestamp preservation
- Amendment history
- Void reason tracking

## Performance Considerations

### Event Stream Optimization

- Aggregate snapshotting for high-volume customers
- Event projection caching
- Batch processing for bulk operations

### Query Optimization

- Read model projections for reporting
- Indexed search capabilities
- Pagination for large datasets

## Error Handling

### Command Failures

- Validation error responses
- Compensation events for rollback
- Retry logic for transient failures

### Integration Failures

- Event replay capabilities
- Dead letter queue for failed events
- Circuit breaker for external services

## Configuration Management

### System Parameters

- Invoice numbering schemes
- Tax calculation methods
- Finance charge settings
- Aging bucket definitions
- Default GL account mappings

### Customer-Specific Settings

- Payment terms
- Credit limits
- Pricing tiers
- Tax exemptions
- Statement preferences

## Migration Support

### Beginning Balance Import

- Customer balance posting
- Historical invoice import
- Open credit migration
- Aging preservation

### Data Import/Export

- CSV/JSON format support
- Field mapping configuration
- Validation and error reporting
- Batch processing capabilities

# Accounts Receivables Business Logic - Part 3

## Master Records Management (Continued)

### 8. Inventory Type Management

#### 8.1 Commands

```elixir
defmodule AccountsReceivables.Commands.CreateInventoryType do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshCommanded.Extension]

  attributes do
    attribute :inventory_type_id, :uuid, allow_nil?: false
    attribute :code, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    attribute :default_item_desc, :string
    attribute :item_class, :string
    attribute :product_line, :string
    attribute :unit_of_measure, :string
    
    # Settings
    attribute :cost_method, :atom, 
      constraints: [one_of: [:average, :fifo, :lifo, :specific_id]]
    attribute :quantity_decimals, :integer, default: 2
    attribute :unit_price, :decimal
    attribute :standard_cost, :decimal
    attribute :return_cost, :decimal
    attribute :repair_charge, :decimal
    attribute :min_restock_amount, :decimal
    attribute :restocking_percentage, :decimal
    
    # Revenue tracking
    attribute :revenue_code_id, :uuid
    attribute :inventory_gl_account_id, :uuid
    attribute :in_transit_inventory_gl_account_id, :uuid
    
    # Lot control settings
    attribute :use_lot_control, :boolean, default: false
    attribute :print_lot_on_invoice, :boolean, default: false
    
    # Kit settings
    attribute :is_kit_item, :boolean, default: false
    attribute :require_prebuild, :boolean, default: false
    attribute :use_kit_number, :boolean, default: false
    attribute :customizable, :boolean, default: false
    
    # General settings
    attribute :update_on_hand, :boolean, default: true
    attribute :check_on_hand, :boolean, default: true
    attribute :allow_negative_qty_on_hand, :boolean, default: false
    attribute :allow_negative_price, :boolean, default: false
    attribute :allow_negative_qty_on_invoice, :boolean, default: false
    attribute :allow_discarding, :boolean, default: false
    attribute :allow_repairing, :boolean, default: false
    attribute :print_serial_on_invoice, :boolean, default: false
    attribute :taxable, :boolean, default: true
    
    # Overwrite permissions
    attribute :allow_overwrite_description, :boolean, default: false
    attribute :allow_overwrite_price, :boolean, default: false
    attribute :allow_overwrite_discount, :boolean, default: false
    attribute :allow_overwrite_tax_status, :boolean, default: false
    attribute :allow_overwrite_weight, :boolean, default: false
    attribute :allow_overwrite_revenue_code, :boolean, default: false
    attribute :allow_overwrite_commission, :boolean, default: false
    
    # Revenue Amortization settings
    attribute :amortize, :boolean, default: false
    attribute :amortization_method, :atom
    attribute :recurring_cycle, :atom
    attribute :number_of_cycles, :integer
    
    # GL Accounts
    attribute :contract_costs_gl_account_id, :uuid
    attribute :contract_obligations_gl_account_id, :uuid
    attribute :contract_discounts_gl_account_id, :uuid
  end
end
```

#### 8.2 Events

```elixir
defmodule AccountsReceivables.Events.InventoryTypeCreated do
  use Ash.Resource,
    data_layer: :embedded
    
  attributes do
    # Include all attributes from CreateInventoryType command
    # ... (same as command attributes)
  end
end
```

#### 8.3 Aggregates

```elixir
defmodule AccountsReceivables.Aggregates.InventoryType do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCommanded.Aggregate]

  postgres do
    table "inventory_types"
    repo AccountsReceivables.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :code, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    attribute :settings, :map, default: %{}
    attribute :lot_control_settings, :map, default: %{}
    attribute :kit_settings, :map, default: %{}
    attribute :gl_accounts, :map, default: %{}
    attribute :permissions, :map, default: %{}
    
    timestamps()
  end
  
  relationships do
    has_many :inventory_items, AccountsReceivables.Aggregates.InventoryItem
  end

  calculations do
    calculate :in_use, :boolean do
      expr(count(inventory_items) > 0)
    end
  end
end
```

### 9. Revenue Code Management

#### 9.1 Commands

```elixir
defmodule AccountsReceivables.Commands.CreateRevenueCode do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshCommanded.Extension]

  attributes do
    attribute :revenue_code_id, :uuid, allow_nil?: false
    attribute :code, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    
    # GL Account mappings
    attribute :sales_revenue_gl_account_id, :uuid, allow_nil?: false
    attribute :sales_returns_gl_account_id, :uuid, allow_nil?: false
    attribute :sales_discounts_gl_account_id, :uuid, allow_nil?: false
    attribute :cost_of_goods_sold_gl_account_id, :uuid, allow_nil?: false
  end
end
```

#### 9.2 Aggregates

```elixir
defmodule AccountsReceivables.Aggregates.RevenueCode do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCommanded.Aggregate]

  postgres do
    table "revenue_codes"
    repo AccountsReceivables.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :code, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    attribute :gl_accounts, :map, allow_nil?: false
    
    timestamps()
  end

  calculations do
    calculate :gl_account_names, :map do
      # Would fetch GL account names from GL module
    end
  end
end
```

### 10. Freight Code Management

#### 10.1 Commands

```elixir
defmodule AccountsReceivables.Commands.CreateFreightCode do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshCommanded.Extension]

  attributes do
    attribute :freight_code_id, :uuid, allow_nil?: false
    attribute :code, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    attribute :min_freight_charge, :decimal
    attribute :taxable, :boolean, default: false
    attribute :freight_revenue_gl_account_id, :uuid, allow_nil?: false
    
    # Weight-based pricing
    attribute :calculate_by_weight, :boolean, default: false
    attribute :weight_brackets, {:array, :map}, default: []
    # Each bracket: %{weight_not_over: decimal, freight_charge: decimal}
  end
end
```

### 11. Salesperson Management

#### 11.1 Commands

```elixir
defmodule AccountsReceivables.Commands.CreateSalesperson do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshCommanded.Extension]

  attributes do
    attribute :salesperson_id, :uuid, allow_nil?: false
    attribute :code, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false
    attribute :title, :string
    attribute :address, :map
    attribute :phone, :string
    attribute :status, :atom, default: :active
    attribute :revenue_code_id, :uuid
    attribute :created_date, :date
  end
end
```

#### 11.2 Aggregates

```elixir
defmodule AccountsReceivables.Aggregates.Salesperson do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCommanded.Aggregate]

  postgres do
    table "salespersons"
    repo AccountsReceivables.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :code, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false
    attribute :contact_info, :map, default: %{}
    attribute :status, :atom, default: :active
    attribute :revenue_code_id, :uuid
    attribute :notes, :text
    
    timestamps()
  end

  relationships do
    has_many :sales_transactions, AccountsReceivables.Aggregates.SalesTransaction
  end

  calculations do
    calculate :total_sales, :decimal do
      # Aggregate sales from related transactions
    end
    
    calculate :monthly_sales, :map do
      # Monthly breakdown of sales
    end
  end
end
```

### 12. Sales Tax Management

#### 12.1 Tax Entity Commands

```elixir
defmodule AccountsReceivables.Commands.CreateTaxEntity do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshCommanded.Extension]

  attributes do
    attribute :tax_entity_id, :uuid, allow_nil?: false
    attribute :code, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    attribute :status, :atom, default: :active
    
    attribute :sales_tax_payable_gl_account_id, :uuid, allow_nil?: false
    attribute :sales_tax_costs_gl_account_id, :uuid, allow_nil?: false
    
    attribute :tax_rate, :decimal, allow_nil?: false
    attribute :min_taxable_amount, :decimal, default: 0
    attribute :exclude_min_in_computation, :boolean, default: false
    attribute :max_taxable_amount, :decimal
    
    attribute :min_tax_amount, :decimal, default: 0
    attribute :max_tax_amount, :decimal
    
    attribute :rounding_method, :atom, 
      constraints: [one_of: [:higher, :nearest, :lower]]
    attribute :rounding_base, :decimal
  end
end
```

#### 12.2 Tax Code Commands

```elixir
defmodule AccountsReceivables.Commands.CreateTaxCode do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshCommanded.Extension]

  attributes do
    attribute :tax_code_id, :uuid, allow_nil?: false
    attribute :code, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    
    # Up to 3 tax entities
    attribute :tax_entity_1_id, :uuid
    attribute :tax_entity_2_id, :uuid
    attribute :tax_entity_3_id, :uuid
  end
end
```

#### 12.3 Tax Aggregates

```elixir
defmodule AccountsReceivables.Aggregates.TaxCode do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCommanded.Aggregate]

  postgres do
    table "tax_codes"
    repo AccountsReceivables.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :code, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    attribute :tax_entities, {:array, :uuid}, default: []
    
    timestamps()
  end

  calculations do
    calculate :effective_rate, :decimal do
      # Calculate combined rate from all entities
    end
    
    calculate :tax_details, :map do
      # Detailed breakdown of tax calculation rules
    end
  end
end
```

### 13. Payment Code Management

#### 13.1 Commands

```elixir
defmodule AccountsReceivables.Commands.CreatePayCode do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshCommanded.Extension]

  attributes do
    attribute :pay_code_id, :uuid, allow_nil?: false
    attribute :code, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    attribute :bank_id, :uuid
    
    attribute :type, :atom, 
      constraints: [one_of: [:cash, :check, :credit_card, :cod, :terms, :ach, :other]]
    
    attribute :use_in_sales, :boolean, default: true
    attribute :use_in_purchases, :boolean, default: true
    attribute :apply_payment_automatically, :boolean, default: false
    attribute :eligible_for_finance_charges, :boolean, default: true
    
    # Terms settings (when type = :terms)
    attribute :discount_percentage, :decimal
    attribute :discount_days_type, :atom, 
      constraints: [one_of: [:from_invoice_date, :date_table]]
    attribute :discount_days, :integer
    attribute :net_days, :integer
    attribute :date_table, {:array, :map}, default: []
    # Date table entries: %{start_date: integer, end_date: integer, 
    #                       discount_date: integer, due_date: integer, 
    #                       months_to_add: integer}
  end
end
```

### 14. System Remark Management

#### 14.1 Commands

```elixir
defmodule AccountsReceivables.Commands.CreateSystemRemark do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshCommanded.Extension]

  attributes do
    attribute :remark_id, :uuid, allow_nil?: false
    attribute :code, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    attribute :remark_text, :text, allow_nil?: false
    attribute :applicable_to, {:array, :atom}, 
      default: [:invoices, :sales_orders, :quotes]
  end
end
```

### 15. Bank Account Management

#### 15.1 Commands

```elixir
defmodule AccountsReceivables.Commands.CreateBankAccount do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshCommanded.Extension]

  attributes do
    attribute :bank_account_id, :uuid, allow_nil?: false
    attribute :bank_number, :string, allow_nil?: false
    attribute :bank_name, :string, allow_nil?: false
    attribute :account_description, :string
    attribute :account_number, :string, allow_nil?: false
    attribute :routing_number, :string
    attribute :gl_account_id, :uuid, allow_nil?: false
    attribute :currency_code, :string, default: "USD"
    
    attribute :account_type, :atom, 
      constraints: [one_of: [:checking, :savings, :other]]
    attribute :check_format, :atom, 
      constraints: [one_of: [:standard_us, :canadian]]
    
    # Check numbering
    attribute :use_system_generated_deposit_number, :boolean, default: true
    attribute :checks_share_numbering, :boolean, default: false
    attribute :next_deposit_number, :integer, default: 1
    attribute :next_computer_check_number, :integer, default: 1
    attribute :next_handwritten_check_number, :integer, default: 1
    
    # Limits
    attribute :max_computer_check_amount, :decimal
    attribute :max_handwritten_check_amount, :decimal
    
    # Module availability
    attribute :available_in_accounts_payable, :boolean, default: true
    attribute :available_in_payroll, :boolean, default: false
    attribute :available_in_sales_and_receivables, :boolean, default: true
    
    # Reconciliation
    attribute :previous_statement_date, :date
    attribute :previous_statement_balance, :decimal, default: 0
  end
end
```

#### 15.2 Bank Account Aggregates

```elixir
defmodule AccountsReceivables.Aggregates.BankAccount do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCommanded.Aggregate]

  postgres do
    table "bank_accounts"
    repo AccountsReceivables.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :bank_number, :string, allow_nil?: false
    attribute :bank_name, :string, allow_nil?: false
    attribute :account_info, :map, allow_nil?: false
    attribute :check_settings, :map, default: %{}
    attribute :reconciliation_info, :map, default: %{}
    attribute :electronic_payment_settings, :map
    attribute :positive_pay_settings, :map
    
    timestamps()
  end

  relationships do
    has_many :deposits, AccountsReceivables.Aggregates.BankDeposit
    has_many :receipts, AccountsReceivables.Aggregates.Receipt
  end

  calculations do
    calculate :current_balance, :decimal do
      # Calculate from transactions
    end
    
    calculate :unreconciled_amount, :decimal do
      # Calculate unreconciled transactions
    end
  end
end
```

### 16. Multi-Currency Support

#### 16.1 Currency Code Commands

```elixir
defmodule AccountsReceivables.Commands.CreateCurrencyCode do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshCommanded.Extension]

  attributes do
    attribute :currency_code_id, :uuid, allow_nil?: false
    attribute :code, :string, allow_nil?: false
    attribute :symbol, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    
    attribute :exchange_method, :atom, 
      constraints: [one_of: [:home_to_foreign, :foreign_to_home]]
    attribute :exchange_rate, :decimal, allow_nil?: false
    attribute :exchange_rate_date, :date, allow_nil?: false
    
    attribute :exchange_gain_loss_gl_account_id, :uuid
  end
end

defmodule AccountsReceivables.Commands.UpdateExchangeRate do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshCommanded.Extension]

  attributes do
    attribute :currency_code_id, :uuid, allow_nil?: false
    attribute :new_exchange_rate, :decimal, allow_nil?: false
    attribute :effective_date, :date, allow_nil?: false
  end
end
```

### 17. Activity Management

#### 17.1 Activity Type Commands

```elixir
defmodule AccountsReceivables.Commands.CreateActivityType do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshCommanded.Extension]

  attributes do
    attribute :activity_type_id, :uuid, allow_nil?: false
    attribute :code, :string, allow_nil?: false
    attribute :description, :string, allow_nil?: false
    
    attribute :status_options, {:array, :map}, default: []
    # Each status: %{sequence: integer, status: string, description: string}
    
    attribute :access_rights, {:array, :map}, default: []
    # Each right: %{user_or_group: string, can_view: boolean, can_update: boolean}
  end
end
```

### 18. Inventory Pricing

#### 18.1 Basic Price Commands

```elixir
defmodule AccountsReceivables.Commands.SetInventoryBasicPrice do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshCommanded.Extension]

  attributes do
    attribute :inventory_item_id, :uuid, allow_nil?: false
    attribute :price_id, :uuid, allow_nil?: false
    
    attribute :unit_of_measure, :string
    attribute :specification_code, :string
    attribute :unit_price, :decimal, allow_nil?: false
    attribute :effective_date, :date
    attribute :expiry_date, :date
  end
end
```

#### 18.2 Multi-Level Price Commands

```elixir
defmodule AccountsReceivables.Commands.SetInventoryMultiLevelPrice do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshCommanded.Extension]

  attributes do
    attribute :inventory_item_id, :uuid, allow_nil?: false
    attribute :price_level_id, :uuid, allow_nil?: false
    
    attribute :price_code, :string, allow_nil?: false
    attribute :quantity_breaks, {:array, :map}, default: []
    # Each break: %{min_quantity: decimal, max_quantity: decimal, 
    #               unit_price: decimal, discount_percentage: decimal}
  end
end
```

## Process Managers

### Master Data Process Manager

```elixir
defmodule AccountsReceivables.ProcessManagers.MasterDataProcessManager do
  use Commanded.ProcessManagers.ProcessManager,
    application: AccountsReceivables.Commanded.Application,
    name: "MasterDataProcessManager"

  @derive Jason.Encoder
  defstruct [
    :inventory_types,
    :revenue_codes,
    :tax_codes,
    :pay_codes,
    :bank_accounts,
    :currency_codes,
    :validation_errors
  ]

  def interested?(%InventoryTypeCreated{inventory_type_id: id}), 
    do: {:start, id}
  def interested?(%RevenueCodeCreated{revenue_code_id: id}), 
    do: {:start, id}
  def interested?(%TaxCodeCreated{tax_code_id: id}), 
    do: {:start, id}
  def interested?(%BankAccountCreated{bank_account_id: id}), 
    do: {:start, id}
  def interested?(_event), do: false

  def handle(%__MODULE__{} = state, %InventoryTypeCreated{} = event) do
    # Validate relationships (revenue code, GL accounts)
    # Ensure cost method cannot be changed after creation
    # Set up default warehouse assignments
    
    commands = [
      %ValidateInventoryTypeRelationships{
        inventory_type_id: event.inventory_type_id,
        revenue_code_id: event.revenue_code_id,
        gl_account_ids: extract_gl_accounts(event)
      }
    ]
    
    {commands, %{state | inventory_types: Map.put(state.inventory_types || %{}, 
                                                   event.inventory_type_id, 
                                                   event)}}
  end

  def handle(%__MODULE__{} = state, %TaxCodeCreated{} = event) do
    # Validate tax entities exist
    # Calculate combined tax rate
    # Update customer default tax codes if applicable
    
    commands = [
      %ValidateTaxEntities{
        tax_code_id: event.tax_code_id,
        entity_ids: [event.tax_entity_1_id, event.tax_entity_2_id, event.tax_entity_3_id]
      }
    ]
    
    {commands, %{state | tax_codes: Map.put(state.tax_codes || %{}, 
                                            event.tax_code_id, 
                                            event)}}
  end

  def handle(%__MODULE__{} = state, %BankAccountCreated{} = event) do
    # Validate GL account
    # Set up check printing configuration
    # Initialize reconciliation state
    
    commands = [
      %InitializeBankReconciliation{
        bank_account_id: event.bank_account_id,
        previous_balance: event.previous_statement_balance || Decimal.new(0),
        previous_date: event.previous_statement_date
      }
    ]
    
    {commands, %{state | bank_accounts: Map.put(state.bank_accounts || %{}, 
                                                event.bank_account_id, 
                                                event)}}
  end

  defp extract_gl_accounts(event) do
    [
      event.inventory_gl_account_id,
      event.in_transit_inventory_gl_account_id,
      event.contract_costs_gl_account_id,
      event.contract_obligations_gl_account_id,
      event.contract_discounts_gl_account_id
    ]
    |> Enum.reject(&is_nil/1)
  end
end
```

### Exchange Rate Process Manager

```elixir
defmodule AccountsReceivables.ProcessManagers.ExchangeRateProcessManager do
  use Commanded.ProcessManagers.ProcessManager,
    application: AccountsReceivables.Commanded.Application,
    name: "ExchangeRateProcessManager"

  @derive Jason.Encoder
  defstruct [
    :currency_codes,
    :pending_transactions,
    :rate_history
  ]

  def interested?(%CurrencyCodeCreated{currency_code_id: id}), 
    do: {:start, id}
  def interested?(%ExchangeRateUpdated{currency_code_id: id}), 
    do: {:continue, id}
  def interested?(_event), do: false

  def handle(%__MODULE__{} = state, %ExchangeRateUpdated{} = event) do
    # Update all pending transactions with new rate if configured
    # Calculate exchange gains/losses
    # Post to GL if required
    
    affected_transactions = find_affected_transactions(state, event.currency_code_id)
    
    commands = Enum.map(affected_transactions, fn transaction ->
      %RecalculateForeignCurrencyAmount{
        transaction_id: transaction.id,
        old_rate: transaction.exchange_rate,
        new_rate: event.new_exchange_rate,
        effective_date: event.effective_date
      }
    end)
    
    updated_history = Map.update(
      state.rate_history || %{},
      event.currency_code_id,
      [event],
      &([event | &1])
    )
    
    {commands, %{state | rate_history: updated_history}}
  end

  defp find_affected_transactions(state, currency_code_id) do
    # Find open invoices and pending receipts in this currency
    Map.get(state.pending_transactions || %{}, currency_code_id, [])
  end
end
```

## Inter-Module Communication

### Events Published to Other Modules

```elixir
defmodule AccountsReceivables.Events.ForGeneralLedger do
  @moduledoc """
  Events that should be consumed by the General Ledger module
  """

  defmodule GLAccountRequired do
    use Ash.Resource, data_layer: :embedded
    
    attributes do
      attribute :requesting_module, :atom, default: :accounts_receivables
      attribute :entity_type, :atom  # :revenue_code, :tax_entity, :bank_account
      attribute :entity_id, :uuid
      attribute :gl_account_type, :atom  # :revenue, :tax_payable, :cash, etc.
      attribute :required_by, :datetime
    end
  end

  defmodule ExchangeGainLossPosted do
    use Ash.Resource, data_layer: :embedded
    
    attributes do
      attribute :currency_code, :string
      attribute :transaction_id, :uuid
      attribute :gain_loss_amount, :decimal
      attribute :gl_account_id, :uuid
      attribute :posting_date, :date
    end
  end
end
```

### Event Subscriptions from Other Modules

```elixir
defmodule AccountsReceivables.Subscriptions.FromInventory do
  @moduledoc """
  Handle events from the Inventory module
  """

  def handle_inventory_item_created(event) do
    # Update inventory type usage
    # Set up default pricing
    # Initialize available quantity tracking
  end

  def handle_inventory_cost_updated(event) do
    # Update standard costs
    # Recalculate margins on open quotes
  end

  def handle_lot_number_assigned(event) do
    # Track lot numbers for invoicing
    # Update lot control settings
  end
end
```

## Validation and Business Rules

### Master Data Validators

```elixir
defmodule AccountsReceivables.Validators.MasterDataValidator do
  @moduledoc """
  Validates master data consistency and relationships
  """

  def validate_inventory_type_deletion(inventory_type_id) do
    # Check if type is used by any inventory items
    # Check for open transactions
    # Return {:error, reason} if cannot delete
  end

  def validate_revenue_code_change(revenue_code_id, changes) do
    # Ensure GL accounts are valid
    # Check impact on existing transactions
    # Validate tracking method consistency
  end

  def validate_tax_code_configuration(tax_code) do
    # Ensure tax entities exist and are active
    # Validate rate calculations
    # Check for circular dependencies
  end

  def validate_bank_account_currency_change(bank_account_id, new_currency) do
    # This should always fail - currency cannot be changed after creation
    {:error, :currency_change_not_allowed}
  end

  def validate_exchange_rate(currency_code, new_rate, method) do
    # Ensure rate is positive
    # Check rate reasonableness (e.g., not more than 50% change)
    # Validate based on exchange method
  end
end
```

## Access Control

### Master Data Permissions

```elixir
defmodule AccountsReceivables.Policies.MasterDataPolicy do
  use Ash.Policy.Authorizer

  policies do
    policy action(:create_inventory_type) do
      authorize_if role: [:admin, :inventory_manager]
    end

    policy action(:update_tax_code) do
      authorize_if role: [:admin, :finance_manager]
      forbid_if expr(is_system_tax_code == true)
    end

    policy action(:delete_revenue_code) do
      authorize_if role: :admin
      forbid_if expr(in_use == true)
    end

    policy action(:update_exchange_rate) do
      authorize_if role: [:admin, :finance_manager]
      forbid_if expr(is_home_currency == true)
    end

    policy action(:manage_bank_accounts) do
      authorize_if role: [:admin, :treasury_manager]
    end
  end
end
```

## Reporting Queries

### Master Data Reports

```elixir
defmodule AccountsReceivables.Queries.MasterDataQueries do
  import Ecto.Query

  def list_active_inventory_types(filters \\ %{}) do
    InventoryType
    |> where([t], t.status == :active)
    |> filter_by_class(filters[:item_class])
    |> filter_by_product_line(filters[:product_line])
    |> preload([:revenue_code, :inventory_items])
  end

  def tax_code_summary(tax_code_id) do
    TaxCode
    |> where([tc], tc.id == ^tax_code_id)
    |> join(:left, [tc], te1 in TaxEntity, on: tc.tax_entity_1_id == te1.id)
    |> join(:left, [tc], te2 in TaxEntity, on: tc.tax_entity_2_id == te2.id)
    |> join(:left, [tc], te3 in TaxEntity, on: tc.tax_entity_3_id == te3.id)
    |> select([tc, te1, te2, te3], %{
      code: tc.code,
      description: tc.description,
      combined_rate: fragment("COALESCE(?, 0) + COALESCE(?, 0) + COALESCE(?, 0)",
                              te1.tax_rate, te2.tax_rate, te3.tax_rate),
      entities: [te1, te2, te3]
    })
  end

  def bank_reconciliation_status(bank_account_id) do
    BankAccount
    |> where([ba], ba.id == ^bank_account_id)
    |> join(:left, [ba], d in assoc(ba, :deposits))
    |> join(:left, [ba], r in assoc(ba, :receipts))
    |> select([ba, d, r], %{
      account: ba,
      current_balance: ba.current_balance,
      unreconciled_deposits: fragment("COUNT(?) FILTER (WHERE ? IS NULL)", 
                                      d.id, d.reconciled_date),
      unreconciled_receipts: fragment("COUNT(?) FILTER (WHERE ? IS NULL)", 
                                      r.id, r.reconciled_date),
      unreconciled_amount: ba.unreconciled_amount
    })
  end

  def exchange_rate_history(currency_code, date_range) do
    ExchangeRateHistory
    |> where([erh], erh.currency_code == ^currency_code)
    |> where([erh], erh.effective_date >= ^date_range.start_date)
    |> where([erh], erh.effective_date <= ^date_range.end_date)
    |> order_by([erh], desc: erh.effective_date)
  end
end
```

## Configuration Management

### Module Settings

```elixir
defmodule AccountsReceivables.Config do
  @moduledoc """
  Configuration settings for Accounts Receivables module
  """

  def inventory_type_defaults do
    %{
      cost_method: :average,
      quantity_decimals: 2,
      update_on_hand: true,
      check_on_hand: true,
      taxable: true,
      allow_negative_qty_on_hand: false
    }
  end

  def tax_calculation_settings do
    %{
      rounding_method: :nearest,
      rounding_base: Decimal.new("0.01"),
      compound_taxes: false,
      tax_on_shipping: true,
      tax_on_freight: false
    }
  end

  def bank_account_defaults do
    %{
      account_type: :checking,
      check_format: :standard_us,
      use_system_generated_deposit_number: true,
      checks_share_numbering: false,
      next_deposit_number: 1,
      next_computer_check_number: 1001,
      next_handwritten_check_number: 5001
    }
  end

  def multi_currency_settings do
    %{
      home_currency: "USD",
      exchange_method: :home_to_foreign,
      auto_update_rates: false,
      rate_variance_threshold: Decimal.new("0.50"), # 50% change triggers warning
      require_approval_for_rate_changes: true
    }
  end
end
```

## Integration Points

### With General Ledger Module

- All GL account references must be validated
- Exchange gains/losses posted automatically
- Tax liability accounts updated
- Bank reconciliation entries synchronized

### With Inventory Module

- Inventory type assignments
- Cost method enforcement
- Lot control integration
- Kit configuration support

### With Sales Order Module

- Revenue code usage
- Tax code application
- Freight calculations
- Salesperson assignments

### With Banking Module

- Bank account management
- Check printing configuration
- Electronic payment setup
- Positive pay file generation

## End of Part 3

This completes Part 3 of the Accounts Receivables business logic implementation, covering master records management, multi-currency support, tax configuration, and integration points with other modules.

# Accountex Accounts Receivables Business Logic Part 4

## Design specification for period-end operations

Based on research of event-sourced patterns using Commanded and AshCommanded frameworks, this specification presents Part 4 of the Accountex Accounts Receivables business logic, covering Period-End Closing, Set Up Parameters, Update GL Account Balances, and Multi-Currency Revaluation features.

## Architecture Foundation

The design follows **CQRS/ES architecture patterns** established in Elixir applications using Commanded, implementing strict command/query separation with an append-only event store backed by PostgreSQL. Each business operation processes through aggregates that maintain consistency boundaries, emit domain events, and use process managers for complex workflow orchestration.

## Feature 1: Period-End Closing

### Domain Model and Aggregates

The period-end closing process centers around two main aggregates:

- **AccountingPeriod**: Manages the lifecycle and state transitions of accounting periods
- **ARClosingProcess**: Orchestrates the complete period-end closing workflow

### Command Structure

```elixir
defmodule Accountex.AccountsReceivables.Commands.InitiatePeriodClose do
  @derive Jason.Encoder
  defstruct [:period_id, :closing_date, :initiated_by, :closing_options]
end

defmodule Accountex.AccountsReceivables.Commands.ValidateTransactions do
  @derive Jason.Encoder
  defstruct [:period_id, :validation_rules]
end

defmodule Accountex.AccountsReceivables.Commands.PerformAgingCalculation do
  @derive Jason.Encoder
  defstruct [:period_id, :aging_buckets, :calculation_date]
end
```

### Event Definitions

```elixir
defmodule Accountex.AccountsReceivables.Events.PeriodCloseInitiated do
  @derive Jason.Encoder
  defstruct [:period_id, :closing_date, :initiated_by, :initiated_at, :status]
end

defmodule Accountex.AccountsReceivables.Events.TransactionValidationCompleted do
  @derive Jason.Encoder  
  defstruct [:period_id, :validation_results, :invalid_transactions, :validated_at]
end
```

The period closing enforces **critical business rules**: periods can only be closed when all transactions are validated, aging calculations are current within 24 hours, outstanding reconciliation items are resolved, and GL integration is confirmed. The system maintains complete audit trails throughout the closing process.

### Process Manager Implementation

```elixir
defmodule Accountex.AccountsReceivables.ProcessManagers.PeriodEndClosingProcessManager do
  use Commanded.ProcessManagers.ProcessManager,
    name: "PeriodEndClosingProcessManager",
    router: Accountex.CommandRouter

  def handle(%PeriodEndClosingProcessManager{}, %PeriodCloseInitiated{} = event) do
    [
      %ValidateTransactions{period_id: event.period_id},
      %PerformAgingCalculation{period_id: event.period_id},
      %InitiateGLSync{sync_date: event.closing_date, period_id: event.period_id}
    ]
  end
end
```

## Feature 2: Set Up Parameters

### Configuration Management Design

The parameter setup functionality manages system-wide AR configuration through dedicated aggregates:

- **ARConfiguration**: Handles global AR settings and processing rules
- **AgingConfiguration**: Specifically manages aging bucket definitions

### Command and Event Structure

```elixir
defmodule Accountex.AccountsReceivables.Commands.DefineAgingBuckets do
  @derive Jason.Encoder
  defstruct [:configuration_id, :buckets, :effective_date, :configured_by]
end

defmodule Accountex.AccountsReceivables.Events.AgingBucketsDefined do
  @derive Jason.Encoder
  defstruct [:configuration_id, :buckets, :effective_date, :configured_by, :configured_at]
end
```

Configuration parameters include **aging bucket definitions** with non-overlapping day ranges, **payment terms** with calculation methods and due date logic, **GL account mappings** linking AR operations to chart of accounts, and **processing rules** defining automated behaviors and thresholds. All configuration changes require appropriate authorization levels and maintain full audit history.

## Feature 3: Update GL Account Balances

### Integration Architecture

GL balance updates utilize specialized aggregates for maintaining consistency:

- **GLIntegration**: Manages integration state and synchronization processes
- **BalanceReconciliation**: Handles reconciliation between AR and GL modules

### Synchronization Commands

```elixir
defmodule Accountex.AccountsReceivables.Commands.InitiateGLSync do
  @derive Jason.Encoder
  defstruct [:sync_id, :sync_date, :account_filters, :initiated_by]
end

defmodule Accountex.AccountsReceivables.Commands.PostGLJournals do
  @derive Jason.Encoder
  defstruct [:sync_id, :journal_entries, :posting_reference]
end
```

The GL integration ensures **data consistency** through automated balance synchronization, journal entry generation following double-entry principles, reconciliation processes identifying discrepancies, and posting validation against open GL periods. All synchronization maintains detailed audit trails and supports rollback capabilities.

### Read Model Projection

```elixir
defmodule Accountex.AccountsReceivables.Projections.GLBalanceReconciliationProjection do
  use Commanded.Projections.Ecto, name: "gl_balance_reconciliation_projection"
  
  project %BalancesReconciled{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :reconciliation, %BalanceReconciliation{
      reconciliation_id: event.reconciliation_id,
      results: event.reconciliation_results,
      discrepancies: event.discrepancies,
      reconciled_at: event.reconciled_at
    })
  end
end
```

## Feature 4: Multi-Currency Revaluation

### Currency Management Design

Multi-currency revaluation implements sophisticated foreign exchange handling through:

- **CurrencyRevaluation**: Orchestrates revaluation processes
- **ExchangeRateManager**: Maintains exchange rate data and calculations

### Revaluation Commands and Events

```elixir
defmodule Accountex.AccountsReceivables.Commands.InitiateCurrencyRevaluation do
  @derive Jason.Encoder
  defstruct [:revaluation_id, :base_currency, :revaluation_date, :currencies, :initiated_by]
end

defmodule Accountex.AccountsReceivables.Commands.CalculateRevaluationGains do
  @derive Jason.Encoder
  defstruct [:revaluation_id, :customer_balances, :new_rates, :calculation_date]
end

defmodule Accountex.AccountsReceivables.Events.RevaluationGainsCalculated do
  @derive Jason.Encoder
  defstruct [:revaluation_id, :calculation_results, :total_gain_loss, :calculated_at]
end
```

The revaluation process **preserves original transaction currencies** while calculating unrealized gains/losses based on current exchange rates. The system uses officially recognized rate sources, posts adjustments to designated GL accounts, maintains compliance with accounting standards, and provides comprehensive reporting of foreign exchange impacts.

## Integration Points and Process Orchestration

### Cross-Module Integration

The system integrates with multiple modules through well-defined interfaces:

**General Ledger Module**: Posts journal entries through standardized interfaces, maintains real-time balance synchronization, coordinates period status across modules, and validates all GL account references against the chart of accounts.

**Multi-Currency Engine**: Receives exchange rate feeds from authorized providers, provides conversion calculation services, triggers automatic revaluation based on rate movements, and maintains historical rate archives for audit purposes.

**Reporting Services**: Generates period-end reports including aging analysis and trial balances, provides configuration reports showing current parameter settings, and maintains comprehensive audit trails of all events and changes.

### Complex Workflow Management

Process managers orchestrate multi-step operations across aggregates:

```elixir
defmodule Accountex.AccountsReceivables.ProcessManagers.GLIntegrationProcessManager do
  use Commanded.ProcessManagers.ProcessManager,
    name: "GLIntegrationProcessManager"

  def interested?(%GLSyncInitiated{sync_id: sync_id}), do: {:start, sync_id}
  def interested?(%BalanceUpdatesProcessed{sync_id: sync_id}), do: {:continue, sync_id}
  def interested?(%GLJournalsPosted{sync_id: sync_id}), do: {:stop, sync_id}
  
  def handle(%GLIntegrationProcessManager{}, %GLSyncInitiated{} = event) do
    [
      %ProcessBalanceUpdates{sync_id: event.sync_id},
      %ReconcileBalances{sync_id: event.sync_id}
    ]
  end
end
```

## Business Rules and Validation Framework

### Critical Validation Rules

**Period-End Closing** requires all customer invoices properly applied, credit memos and payments matched, disputed amounts identified and segregated, aging calculations current and accurate, and GL integration complete and balanced.

**Configuration Management** enforces aging bucket completeness with non-overlapping ranges, valid calculation methods for payment terms, active GL account references in mappings, and comprehensive audit trails for all changes.

**GL Integration** maintains mathematical accuracy in all balance updates, follows standard accounting principles for journal entries, restricts posting to open periods only, and ensures cross-module reconciliations balance perfectly.

**Currency Revaluation** validates exchange rates from authorized sources only, properly classifies revaluation gains and losses, preserves historical rates for audit purposes, and meets all regulatory compliance requirements.

## Error Handling and Recovery Strategies

### Command Validation and Failure Management

The system implements comprehensive error handling through multiple layers. Invalid command structures are rejected at the boundary with detailed error messages. Business rule violations trigger compensating events to maintain consistency. Authorization failures log security events and notify administrators. Data consistency checks prevent corruption through aggregate invariants.

### Process Manager Recovery

Process managers implement robust recovery mechanisms including compensating transaction patterns for reversing partial operations, state recovery through event replay from the event store, defined manual intervention points for complex failures, and automated error notification systems alerting operations teams.

### Projection Rebuild Capabilities

Read model projections support complete reconstruction through event replay mechanisms for rebuilding from the event store, snapshot strategies reducing rebuild time for large datasets, data validation ensuring integrity after reconstruction, and performance optimization for handling millions of events efficiently.

## Performance Optimization Strategies

### Event Store Optimization

The event store implements proper partitioning by aggregate ID for parallel processing, snapshot strategies preventing large aggregate replay overhead, archiving policies moving historical events to cold storage, and read replica configurations distributing projection load.

### Command Processing Efficiency

Command processing achieves high throughput through concurrent processing of independent commands, batch operations for bulk updates, connection pooling and resource management, and comprehensive monitoring with performance alerting.

### Query Performance

Query optimization ensures fast read operations through strategic indexing on projection tables, materialized views for complex aggregations, intelligent caching of frequently accessed data, and continuous query plan analysis and optimization.

## Summary

This Part 4 specification extends the Accountex Accounts Receivables module with sophisticated period-end operations, following established CQRS/ES patterns using Commanded and AshCommanded. The design ensures data consistency, complete auditability, and scalability while maintaining clean separation between commands and queries. All features integrate seamlessly with existing AR functionality and provide robust business logic for enterprise-grade financial operations.
