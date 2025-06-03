# Customer Resource (Arcust table)
defmodule AccountMate.AR.Customer do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "arcust"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :customer_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :company, :string do
      constraints max_length: 40
    end

    attribute :company2, :string do
      constraints max_length: 40
      description "Alias"
    end

    attribute :addr1, :string do
      constraints max_length: 40
      description "Address 1"
    end

    attribute :addr2, :string do
      constraints max_length: 40
      description "Address 2"
    end

    attribute :city, :string do
      constraints max_length: 30
    end

    attribute :state, :string do
      constraints max_length: 15
    end

    attribute :zip, :string do
      constraints max_length: 10
    end

    attribute :country, :string do
      constraints max_length: 25
    end

    attribute :phone1, :string do
      constraints max_length: 20
      description "Phone 1"
    end

    attribute :phone2, :string do
      constraints max_length: 20
      description "Phone 2"
    end

    attribute :fax, :string do
      constraints max_length: 20
    end

    attribute :email, :string
    attribute :website, :string

    attribute :first_name, :string do
      constraints max_length: 15
    end

    attribute :last_name, :string do
      constraints max_length: 15
    end

    attribute :dear, :string do
      constraints max_length: 15
    end

    attribute :title, :string do
      constraints max_length: 30
    end

    attribute :salesperson_no, :string do
      constraints max_length: 10
    end

    attribute :status, :string do
      constraints max_length: 1
      default "A"
    end

    attribute :class, :string do
      constraints max_length: 10
      description "Customer Class"
    end

    attribute :industry, :string do
      constraints max_length: 10
    end

    attribute :territory, :string do
      constraints max_length: 10
    end

    attribute :warehouse, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :pay_code, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :bill_to_no, :string do
      constraints max_length: 10
      description "Bill To Address #"
    end

    attribute :ship_to_no, :string do
      constraints max_length: 10
      description "Ship To Address #"
    end

    attribute :tax_code, :string do
      constraints max_length: 10
      description "Sales Tax Code"
    end

    attribute :revenue_code, :string do
      constraints max_length: 10
    end

    attribute :commission, :string do
      constraints max_length: 10
    end

    attribute :tax_field1, :string do
      constraints max_length: 16
    end

    attribute :tax_field2, :string do
      constraints max_length: 16
    end

    attribute :ssn_fein, :string do
      constraints max_length: 50
      description "FEIN/SSN"
      allow_nil? false
    end

    attribute :currency_code, :string do
      constraints max_length: 3
      allow_nil? false
    end

    attribute :print_statement_option, :string do
      constraints max_length: 1
      default "O"
      allow_nil? false
      description "O - Print Open Item, B - Print Balance Fwd"
    end

    attribute :ar_account_id, :string do
      constraints max_length: 30
      description "Accounts Receivable GL Account ID"
      allow_nil? false
    end

    attribute :price_code, :string do
      constraints max_length: 10
    end

    attribute :parent_customer_no, :string do
      constraints max_length: 10
    end

    attribute :language, :string do
      constraints max_length: 3
      description "Customer Language"
    end

    attribute :last_invoice_no, :string do
      constraints max_length: 10
    end

    attribute :last_invoice_currency_code, :string do
      constraints max_length: 3
    end

    attribute :last_receipt_no, :string do
      constraints max_length: 10
    end

    attribute :last_receipt_currency_code, :string do
      constraints max_length: 3
    end

    # Bank/Electronic Payment fields
    attribute :bank_account_type, :string do
      constraints max_length: 1
      description "C - Checking, S - Savings"
    end

    attribute :bank_name, :string do
      constraints max_length: 35
    end

    attribute :bank_account, :string do
      constraints max_length: 20
    end

    attribute :bank_route, :string do
      constraints max_length: 9
    end

    attribute :prenote, :string do
      constraints max_length: 1
    end

    attribute :ship_via, :string do
      constraints max_length: 10
    end

    attribute :fob, :string do
      constraints max_length: 10
    end

    attribute :tax_exemption_type, :string do
      constraints max_length: 1
    end

    # Date fields
    attribute :certificate_expiration_date, :date
    attribute :prenote_date, :date
    attribute :last_sales_date, :date
    attribute :last_receipt_date, :date
    attribute :ytd_start_date, :date
    attribute :ytd_recalc_date, :date
    attribute :temp_credit_valid_until, :date

    # Boolean fields
    attribute :print_statement, :boolean, default: false
    attribute :consolidate_statement, :boolean, default: false
    attribute :apply_finance_charge, :boolean, default: false
    attribute :use_in_internet_order, :boolean, default: false
    attribute :use_customer_item_no, :boolean, default: false
    attribute :use_inventory_item_no, :boolean, default: false
    attribute :use_customer_price, :boolean, default: false
    attribute :auto_generate_invoice, :boolean, default: false
    attribute :use_last_customer_price, :boolean, default: false
    attribute :apply_tax, :boolean, default: false
    attribute :price_includes_tax, :boolean, default: false
    attribute :save_card, :boolean, default: false
    attribute :show_notepad_first, :boolean, default: false
    attribute :electronic_payment, :boolean, default: false
    attribute :require_customer_po, :boolean, default: false
    attribute :check_duplicate_customer_po, :boolean, default: false

    # Numeric fields
    attribute :expire_days, :integer, default: 0
    attribute :average_pay_days, :integer
    attribute :discount_rate, :decimal, constraints: [precision: 6, scale: 2], default: 0
    attribute :atd_sales_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :ytd_sales_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :credit_limit, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :temp_credit_increase, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :so_backorder_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :sales_quote_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :open_credit, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :credit_hold_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :uninvoiced_shipment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :balance, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :last_sales_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :last_receipt_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :advanced_bill_payment, :decimal, constraints: [precision: 18, scale: 4], default: 0

    # Collection rates
    attribute :collection_rate1, :integer, default: 0
    attribute :collection_rate2, :integer, default: 0
    attribute :collection_rate3, :integer, default: 0
    attribute :collection_rate4, :integer, default: 0
    attribute :collection_rate5, :integer, default: 0

    # Timestamps
    timestamps()
    attribute :record_modified_date, :utc_datetime
    attribute :recall_date_time, :utc_datetime
    attribute :last_recall_date_time, :utc_datetime
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    has_many :invoices, AccountMate.AR.Invoice do
      source_attribute :customer_no
      destination_attribute :customer_no
    end

    has_many :payments, AccountMate.AR.Payment do
      source_attribute :customer_no
      destination_attribute :customer_no
    end

    has_many :addresses, AccountMate.AR.CustomerAddress do
      source_attribute :customer_no
      destination_attribute :customer_no
    end

    has_many :contacts, AccountMate.AR.CustomerContact do
      source_attribute :customer_no
      destination_attribute :customer_no
    end

    has_many :credit_cards, AccountMate.AR.CustomerCreditCard do
      source_attribute :customer_no
      destination_attribute :customer_no
    end

    belongs_to :salesperson, AccountMate.AR.Salesperson do
      source_attribute :salesperson_no
      destination_attribute :salesperson_no
    end
  end

  identities do
    identity :unique_customer_no, [:customer_no]
  end
end

# Invoice Resource (Arinvc table)
defmodule AccountMate.AR.Invoice do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "arinvc"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :invoice_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :revision, :string do
      constraints max_length: 1
    end

    attribute :type, :string do
      constraints max_length: 1
    end

    attribute :customer_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :warehouse, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :original_invoice_no, :string do
      constraints max_length: 10
      description "Original Invoice # for returns"
    end

    attribute :ordered_by, :string do
      constraints max_length: 30
    end

    attribute :salesperson_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :entered_by, :string do
      constraints max_length: 30
    end

    # Bill To Information
    attribute :bill_to_address_no, :string do
      constraints max_length: 10
    end

    attribute :bill_to_company, :string do
      constraints max_length: 40
    end

    attribute :bill_to_addr1, :string do
      constraints max_length: 40
    end

    attribute :bill_to_addr2, :string do
      constraints max_length: 40
    end

    attribute :bill_to_city, :string do
      constraints max_length: 30
    end

    attribute :bill_to_state, :string do
      constraints max_length: 15
    end

    attribute :bill_to_zip, :string do
      constraints max_length: 10
    end

    attribute :bill_to_country, :string do
      constraints max_length: 25
    end

    attribute :bill_to_phone, :string do
      constraints max_length: 20
    end

    attribute :bill_to_contact, :string do
      constraints max_length: 30
    end

    attribute :bill_to_email, :string

    # Ship To Information
    attribute :ship_to_address_no, :string do
      constraints max_length: 10
    end

    attribute :ship_to_company, :string do
      constraints max_length: 40
    end

    attribute :ship_to_addr1, :string do
      constraints max_length: 40
    end

    attribute :ship_to_addr2, :string do
      constraints max_length: 40
    end

    attribute :ship_to_city, :string do
      constraints max_length: 30
    end

    attribute :ship_to_state, :string do
      constraints max_length: 15
    end

    attribute :ship_to_zip, :string do
      constraints max_length: 10
    end

    attribute :ship_to_country, :string do
      constraints max_length: 25
    end

    attribute :ship_to_phone, :string do
      constraints max_length: 20
    end

    attribute :ship_to_contact, :string do
      constraints max_length: 30
    end

    attribute :ship_to_email, :string

    # Shipping and Payment Information
    attribute :ship_via, :string do
      constraints max_length: 10
    end

    attribute :fob, :string do
      constraints max_length: 10
    end

    attribute :customer_po_no, :string do
      constraints max_length: 20
    end

    attribute :rma_no, :string do
      constraints max_length: 10
    end

    attribute :freight_code, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :freight_tax_code, :string do
      constraints max_length: 10
    end

    attribute :tax_code, :string do
      constraints max_length: 10
    end

    attribute :pay_code, :string do
      constraints max_length: 10
    end

    attribute :bank_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :check_no, :string do
      constraints max_length: 20
    end

    attribute :credit_card_no, :string do
      constraints max_length: 50
    end

    attribute :card_expiration_date, :string do
      constraints max_length: 5
    end

    attribute :cardholder_name, :string do
      constraints max_length: 30
    end

    attribute :payment_reference, :string do
      constraints max_length: 20
    end

    attribute :currency_code, :string do
      constraints max_length: 3
      allow_nil? false
    end

    attribute :ar_account_id, :string do
      constraints max_length: 30
      allow_nil? false
    end

    attribute :posted_to_gl, :string do
      constraints max_length: 1
    end

    attribute :commission, :string do
      constraints max_length: 10
    end

    attribute :source, :string do
      constraints max_length: 10
    end

    attribute :advanced_bill_so_no, :string do
      constraints max_length: 10
    end

    attribute :tax_exemption_type, :string do
      constraints max_length: 1
    end

    # Date fields
    attribute :order_date, :date
    attribute :invoice_date, :date, allow_nil? false
    attribute :discount_date, :date
    attribute :due_date, :date
    attribute :last_paid_date, :date
    attribute :finance_chargeable_date, :date
    attribute :last_finance_charge_date, :date
    attribute :closed_date, :date
    attribute :bill_date, :date

    # Boolean fields
    attribute :voided, :boolean, default: false
    attribute :apply_finance_charge, :boolean, default: true
    attribute :use_customer_item_no, :boolean, default: false
    attribute :freight_taxable1, :boolean, default: false
    attribute :freight_taxable2, :boolean, default: false
    attribute :apply_tax, :boolean, default: false
    attribute :price_includes_tax, :boolean, default: false
    attribute :invoice_printed, :boolean, default: false
    attribute :packing_slip_printed, :boolean, default: false
    attribute :cod_tag_printed, :boolean, default: false
    attribute :label_printed, :boolean, default: false
    attribute :multi_shipment, :boolean, default: false
    attribute :save_credit_card, :boolean, default: false
    attribute :sales_tax_posted, :boolean, default: false

    # Numeric fields - Terms
    attribute :terms_discount_days, :integer, default: 0
    attribute :terms_net_days, :integer, default: 0
    attribute :terms_discount_percent, :decimal, constraints: [precision: 6, scale: 2], default: 0
    attribute :discount_rate, :decimal, constraints: [precision: 6, scale: 2], default: 0

    # Tax versions
    attribute :sales_tax_version, :integer, default: 0
    attribute :freight_sales_tax_version, :integer, default: 0

    # Amount fields in home currency
    attribute :taxable_amount1, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :taxable_amount2, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :sales_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :freight_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :tax_amount1, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :tax_amount2, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :tax_amount3, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :freight_tax_amount1, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :freight_tax_amount2, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :freight_tax_amount3, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :adjustment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :finance_charge_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :total_paid_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :total_discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :total_adjustment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :total_writeoff_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :total_multicurrency_variance, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :multicurrency_rounding, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :balance, :decimal, constraints: [precision: 18, scale: 4], default: 0

    # Foreign currency amounts
    attribute :foreign_taxable_amount1, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_taxable_amount2, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_sales_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_freight_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_tax_amount1, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_tax_amount2, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_tax_amount3, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_freight_tax_amount1, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_freight_tax_amount2, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_freight_tax_amount3, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_adjustment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_finance_charge_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_total_paid_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_total_discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_total_adjustment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_total_writeoff_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_balance, :decimal, constraints: [precision: 18, scale: 4], default: 0

    attribute :weight, :decimal, constraints: [precision: 16, scale: 2], default: 0
    attribute :exchange_rate, :decimal, constraints: [precision: 16, scale: 6], default: 1, allow_nil? false

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :customer, AccountMate.AR.Customer do
      source_attribute :customer_no
      destination_attribute :customer_no
    end

    belongs_to :salesperson, AccountMate.AR.Salesperson do
      source_attribute :salesperson_no
      destination_attribute :salesperson_no
    end

    has_many :line_items, AccountMate.AR.InvoiceLineItem do
      source_attribute :invoice_no
      destination_attribute :invoice_no
    end

    has_many :applied_payments, AccountMate.AR.AppliedPayment do
      source_attribute :invoice_no
      destination_attribute :invoice_no
    end
  end

  identities do
    identity :unique_invoice_no, [:invoice_no]
  end
end

# Invoice Line Item Resource (Aritrs table)
defmodule AccountMate.AR.InvoiceLineItem do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "aritrs"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :invoice_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :customer_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :warehouse, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :so_no, :string do
      constraints max_length: 10
      description "Sales Order #"
    end

    attribute :ship_no, :string do
      constraints max_length: 10
      description "Shipment #"
    end

    attribute :line_item_key, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :rma_no, :string do
      constraints max_length: 10
    end

    attribute :return_code, :string do
      constraints max_length: 2
    end

    attribute :so_line_item, :string do
      constraints max_length: 10
      description "SO Line Item"
    end

    attribute :shipment_line_item, :string do
      constraints max_length: 10
      description "Shipment Line Item"
    end

    attribute :item_no, :string do
      constraints max_length: 20
      allow_nil? false
    end

    attribute :specification_code1, :string do
      constraints max_length: 10
    end

    attribute :specification_code2, :string do
      constraints max_length: 10
    end

    attribute :description, :string do
      constraints max_length: 54
      allow_nil? false
    end

    attribute :unit_of_measure, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :commission, :string do
      constraints max_length: 10
    end

    attribute :status, :string do
      constraints max_length: 1
    end

    attribute :revenue_code, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :bin, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :line_item_tax_code, :string do
      constraints max_length: 10
    end

    attribute :amortization_method, :string do
      constraints max_length: 1
      description "L - Straight-line, S - Specific"
    end

    attribute :amortization_recurring_cycle, :string do
      constraints max_length: 1
      description "W - Weekly, M - Monthly, B - Bi Monthly, Q - Quarterly, S - Semi-Annually, A - Annually"
    end

    attribute :amortization_start_date, :date
    attribute :amortization_end_date, :date

    # Boolean fields
    attribute :kit_item, :boolean, default: false
    attribute :upsell_item, :boolean, default: false
    attribute :stock_item, :boolean, default: true
    attribute :customized_kit_item, :boolean, default: false
    attribute :multiple_bin, :boolean, default: false
    attribute :taxable1, :boolean, default: false
    attribute :taxable2, :boolean, default: false
    attribute :overwrite_remark, :boolean, default: false
    attribute :print_remark, :boolean, default: false
    attribute :print_remark_on_ar_packing_slip, :boolean, default: false
    attribute :amortize, :boolean, default: false
    attribute :last_day, :boolean, default: false
    attribute :drop_ship, :boolean, default: false
    attribute :use_component_price, :boolean, default: false

    # Numeric fields
    attribute :qty_decimal, :integer, default: 0
    attribute :discount_rate, :decimal, constraints: [precision: 6, scale: 2], default: 0
    attribute :line_item_tax_version, :integer, default: 0
    attribute :sales_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :line_item_tax_amount1, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :line_item_tax_amount2, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :line_item_tax_amount3, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_sales_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_line_item_tax_amount1, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_line_item_tax_amount2, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_line_item_tax_amount3, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :order_qty, :decimal, constraints: [precision: 16, scale: 4], default: 0, allow_nil? false
    attribute :ship_qty, :decimal, constraints: [precision: 16, scale: 4], default: 0, allow_nil? false
    attribute :base_uom_factor, :decimal, constraints: [precision: 16, scale: 4], default: 1
    attribute :transaction_uom_factor, :decimal, constraints: [precision: 16, scale: 4], default: 1
    attribute :unit_cost, :decimal, constraints: [precision: 16, scale: 4], default: 0, allow_nil? false
    attribute :unit_price, :decimal, constraints: [precision: 16, scale: 4], default: 0
    attribute :unit_price_plus_tax, :decimal, constraints: [precision: 16, scale: 4], default: 0, allow_nil? false
    attribute :foreign_unit_price, :decimal, constraints: [precision: 16, scale: 4], default: 0, allow_nil? false
    attribute :foreign_unit_price_plus_tax, :decimal, constraints: [precision: 16, scale: 4], default: 0, allow_nil? false
    attribute :weight, :decimal, constraints: [precision: 16, scale: 2], default: 0
    attribute :sequence, :integer, default: 0
    attribute :amortization_cycles, :integer, default: 0

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :invoice, AccountMate.AR.Invoice do
      source_attribute :invoice_no
      destination_attribute :invoice_no
    end

    belongs_to :customer, AccountMate.AR.Customer do
      source_attribute :customer_no
      destination_attribute :customer_no
    end
  end

  identities do
    identity :unique_invoice_line_item, [:invoice_no, :line_item_key]
  end
end

# Payment Resource (Arcash table)
defmodule AccountMate.AR.Payment do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "arcash"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :customer_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :receipt_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :deposit_no, :string do
      constraints max_length: 10
    end

    attribute :pay_code, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :bank_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :check_card_no, :string do
      constraints max_length: 50
    end

    attribute :payment_reference, :string do
      constraints max_length: 20
    end

    attribute :currency_code, :string do
      constraints max_length: 3
      allow_nil? false
    end

    attribute :entered_by, :string do
      constraints max_length: 30
    end

    attribute :posted_to_gl, :string do
      constraints max_length: 1
    end

    attribute :mc_rounding_transfer_to_gl, :string do
      constraints max_length: 1
      description "Multi-Currency Rounding Transfer to GL"
    end

    attribute :paid_date, :date, allow_nil? false
    attribute :last_applied_date, :date, allow_nil? false

    # Boolean fields
    attribute :voided, :boolean, default: false
    attribute :receipt_printed, :boolean, default: false

    # Numeric fields
    attribute :pay_type, :integer, default: 0
    attribute :paid_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :applied_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_paid_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_applied_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :total_multicurrency_variance, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :multicurrency_rounding, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :exchange_rate, :decimal, constraints: [precision: 16, scale: 6], default: 1, allow_nil? false
    attribute :bank_paid_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :customer, AccountMate.AR.Customer do
      source_attribute :customer_no
      destination_attribute :customer_no
    end

    has_many :applied_payments, AccountMate.AR.AppliedPayment do
      source_attribute :receipt_no
      destination_attribute :receipt_no
    end
  end

  identities do
    identity :unique_receipt_no, [:receipt_no]
  end
end

# Applied Payment Resource (Arcapp table)
defmodule AccountMate.AR.AppliedPayment do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "arcapp"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :customer_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :invoice_no, :string do
      constraints max_length: 10
    end

    attribute :receipt_no, :string do
      constraints max_length: 10
    end

    attribute :credit_invoice_no, :string do
      constraints max_length: 10
    end

    attribute :paying_customer_no, :string do
      constraints max_length: 10
    end

    attribute :applied_from_credit_customer_no, :string do
      constraints max_length: 10
    end

    attribute :refund_no, :string do
      constraints max_length: 10
    end

    attribute :ar_credit_account_id, :string do
      constraints max_length: 30
      allow_nil? false
    end

    attribute :payment_discount_gl_account_id, :string do
      constraints max_length: 30
      allow_nil? false
    end

    attribute :payment_adjustment_gl_account_id, :string do
      constraints max_length: 30
      allow_nil? false
    end

    attribute :bad_debt_writeoff_gl_account_id, :string do
      constraints max_length: 30
      allow_nil? false
    end

    attribute :apply_unique_id, :string do
      constraints max_length: 15
    end

    attribute :invoice_unique_id, :string do
      constraints max_length: 15
      allow_nil? false
    end

    attribute :refund_unique_id, :string do
      constraints max_length: 15
    end

    attribute :posted_to_gl, :string do
      constraints max_length: 1
    end

    attribute :applied_date, :date, allow_nil? false

    # Boolean fields
    attribute :voided, :boolean, default: false
    attribute :temporary_field, :boolean, default: false

    # Numeric fields
    attribute :apply_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :adjustment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :writeoff_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :total_tax_claim_back_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :multicurrency_variance_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_apply_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0, allow_nil? false
    attribute :foreign_discount_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_adjustment_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_writeoff_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0
    attribute :foreign_total_tax_claim_back_amount, :decimal, constraints: [precision: 18, scale: 4], default: 0

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :customer, AccountMate.AR.Customer do
      source_attribute :customer_no
      destination_attribute :customer_no
    end

    belongs_to :invoice, AccountMate.AR.Invoice do
      source_attribute :invoice_no
      destination_attribute :invoice_no
    end

    belongs_to :payment, AccountMate.AR.Payment do
      source_attribute :receipt_no
      destination_attribute :receipt_no
    end
  end
end

# Customer Address Resource (Arcadr table)
defmodule AccountMate.AR.CustomerAddress do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "arcadr"
    repo AccountMate.Repo
  end

  attributes do
    attribute :customer_no, :string do
      constraints max_length: 10
      allow_nil? false
      primary_key? true
    end

    attribute :address_no, :string do
      constraints max_length: 10
      allow_nil? false
      primary_key? true
    end

    attribute :company, :string do
      constraints max_length: 40
    end

    attribute :addr1, :string do
      constraints max_length: 40
      description "Address 1"
    end

    attribute :addr2, :string do
      constraints max_length: 40
      description "Address 2"
    end

    attribute :city, :string do
      constraints max_length: 30
    end

    attribute :state, :string do
      constraints max_length: 15
    end

    attribute :zip, :string do
      constraints max_length: 10
    end

    attribute :country, :string do
      constraints max_length: 25
    end

    attribute :phone, :string do
      constraints max_length: 20
    end

    attribute :contact, :string do
      constraints max_length: 30
    end

    attribute :email, :string

    attribute :sales_tax_code, :string do
      constraints max_length: 10
    end

    attribute :ship_via, :string do
      constraints max_length: 10
    end

    attribute :fob, :string do
      constraints max_length: 10
    end

    attribute :tax_exemption_type, :string do
      constraints max_length: 1
    end

    attribute :certificate_expiration_date, :date

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :customer, AccountMate.AR.Customer do
      source_attribute :customer_no
      destination_attribute :customer_no
    end
  end

  identities do
    identity :unique_customer_address, [:customer_no, :address_no]
  end
end

# Customer Contact Resource (Arcont table)
defmodule AccountMate.AR.CustomerContact do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "arcont"
    repo AccountMate.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :customer_no, :string do
      constraints max_length: 10
      allow_nil? false
    end

    attribute :first_name, :string do
      constraints max_length: 15
    end

    attribute :last_name, :string do
      constraints max_length: 15
    end

    attribute :title, :string do
      constraints max_length: 30
    end

    attribute :phone, :string do
      constraints max_length: 20
    end

    attribute :fax, :string do
      constraints max_length: 20
    end

    attribute :email, :string

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    belongs_to :customer, AccountMate.AR.Customer do
      source_attribute :customer_no
      destination_attribute :customer_no
    end
  end
end

# Salesperson Resource (Arslpn table)
defmodule AccountMate.AR.Salesperson do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "arslpn"
    repo AccountMate.Repo
  end

  attributes do
    attribute :salesperson_no, :string do
      constraints max_length: 10
      allow_nil? false
      primary_key? true
    end

    attribute :name, :string do
      constraints max_length: 30
      allow_nil? false
    end

    attribute :title, :string do
      constraints max_length: 30
    end

    attribute :addr1, :string do
      constraints max_length: 40
      description "Address 1"
    end

    attribute :addr2, :string do
      constraints max_length: 40
      description "Address 2"
    end

    attribute :city, :string do
      constraints max_length: 20
    end

    attribute :state, :string do
      constraints max_length: 15
    end

    attribute :zip, :string do
      constraints max_length: 10
    end

    attribute :country, :string do
      constraints max_length: 25
    end

    attribute :phone, :string do
      constraints max_length: 20
    end

    attribute :email, :string

    attribute :status, :string do
      constraints max_length: 1
      default "A"
      allow_nil? false
    end

    attribute :revenue_code, :string do
      constraints max_length: 10
    end

    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  relationships do
    has_many :customers, AccountMate.AR.Customer do
      source_attribute :salesperson_no
      destination_attribute :salesperson_no
    end

    has_many :invoices, AccountMate.AR.Invoice do
      source_attribute :salesperson_no
      destination_attribute :salesperson_no
    end
  end

  identities do
    identity :unique_salesperson_no, [:salesperson_no]
  end
end
