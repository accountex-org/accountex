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
