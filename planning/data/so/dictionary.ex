# Sales Order Main Table (Sosord)
defmodule AccountMate.SalesOrder.SalesOrder do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :so_number, :string do
      description "Sales Order Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :revision, :string do
      description "Revision"
      constraints max_length: 1
    end

    attribute :customer_number, :string do
      description "Customer Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :ordered_by, :string do
      description "Ordered By"
      constraints max_length: 30
    end

    attribute :salesperson_number, :string do
      description "Salesperson Number"
      constraints max_length: 10
    end

    attribute :entered_by, :string do
      description "Entered By"
      constraints max_length: 30
      allow_nil? false
    end

    # Bill To Address Fields
    attribute :bill_to_address_number, :string do
      description "Bill To Address Number"
      constraints max_length: 10
    end

    attribute :bill_to_company, :string do
      description "Bill To Company"
      constraints max_length: 40
    end

    attribute :bill_to_address1, :string do
      description "Bill To Address 1"
      constraints max_length: 40
    end

    attribute :bill_to_address2, :string do
      description "Bill To Address 2"
      constraints max_length: 40
    end

    attribute :bill_to_city, :string do
      description "Bill To City"
      constraints max_length: 30
    end

    attribute :bill_to_state, :string do
      description "Bill To State"
      constraints max_length: 15
    end

    attribute :bill_to_zip, :string do
      description "Bill To Zip"
      constraints max_length: 10
    end

    attribute :bill_to_country, :string do
      description "Bill To Country"
      constraints max_length: 25
    end

    attribute :bill_to_phone, :string do
      description "Bill To Phone"
      constraints max_length: 20
    end

    attribute :bill_to_contact, :string do
      description "Bill To Contact"
      constraints max_length: 30
    end

    attribute :bill_to_email, :string do
      description "Bill To Email Address"
    end

    # Ship To Address Fields
    attribute :ship_to_address_number, :string do
      description "Ship To Address Number"
      constraints max_length: 10
    end

    attribute :ship_to_company, :string do
      description "Ship To Company"
      constraints max_length: 40
    end

    attribute :ship_to_address1, :string do
      description "Ship To Address 1"
      constraints max_length: 40
    end

    attribute :ship_to_address2, :string do
      description "Ship To Address 2"
      constraints max_length: 40
    end

    attribute :ship_to_city, :string do
      description "Ship To City"
      constraints max_length: 30
    end

    attribute :ship_to_state, :string do
      description "Ship To State"
      constraints max_length: 15
    end

    attribute :ship_to_zip, :string do
      description "Ship To Zip"
      constraints max_length: 10
    end

    attribute :ship_to_country, :string do
      description "Ship To Country"
      constraints max_length: 25
    end

    attribute :ship_to_phone, :string do
      description "Ship To Phone"
      constraints max_length: 20
    end

    attribute :ship_to_contact, :string do
      description "Ship To Contact"
      constraints max_length: 30
    end

    attribute :ship_to_email, :string do
      description "Ship To Email Address"
    end

    # Shipping and Payment Info
    attribute :ship_via, :string do
      description "Ship Via"
      constraints max_length: 10
    end

    attribute :fob, :string do
      description "F.O.B."
      constraints max_length: 10
    end

    attribute :customer_po_number, :string do
      description "Customer PO Number"
      constraints max_length: 20
    end

    attribute :freight_code, :string do
      description "Freight Code"
      constraints max_length: 10
    end

    attribute :freight_tax_code, :string do
      description "Freight Sales Tax Code"
      constraints max_length: 10
    end

    attribute :tax_code, :string do
      description "Sales Tax Code"
      constraints max_length: 10
    end

    attribute :pay_code, :string do
      description "Pay Code"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :bank_number, :string do
      description "Bank Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :check_number, :string do
      description "Check Number"
      constraints max_length: 20
    end

    attribute :credit_card_number, :string do
      description "Credit Card Number"
      constraints max_length: 50
    end

    attribute :card_expiry_date, :string do
      description "Card Expiry Date"
      constraints max_length: 5
    end

    attribute :cardholder_name, :string do
      description "Cardholder Name"
      constraints max_length: 30
    end

    attribute :pay_reference, :string do
      description "Pay Reference"
      constraints max_length: 20
    end

    attribute :currency_code, :string do
      description "Currency Code"
      constraints max_length: 3
      allow_nil? false
    end

    attribute :internet_order_number, :string do
      description "Internet Order Number"
      constraints max_length: 10
    end

    attribute :commission, :string do
      description "Commission"
      constraints max_length: 10
    end

    attribute :source, :string do
      description "Source"
      constraints max_length: 10
    end

    attribute :blanket_so_number, :string do
      description "Blanket SO Number"
      constraints max_length: 10
    end

    attribute :tax_exemption_type, :string do
      description "Tax Exemption Type"
      constraints max_length: 1
    end

    attribute :warehouse, :string do
      description "Warehouse"
      constraints max_length: 10
    end

    # Dates
    attribute :create_date, :utc_datetime do
      description "Create Date"
      allow_nil? false
    end

    attribute :order_date, :utc_datetime do
      description "Order Date"
      allow_nil? false
    end

    attribute :quote_date, :utc_datetime do
      description "Quote Date"
    end

    attribute :quote_approval_date, :utc_datetime do
      description "Quote Approval Date"
    end

    # Boolean Flags
    attribute :is_quote, :boolean do
      description "Order or Quote"
      default false
    end

    attribute :on_hold, :boolean do
      description "On-hold"
      default false
    end

    attribute :on_credit_hold, :boolean do
      description "On Credit Hold"
      default false
    end

    attribute :cancelled, :boolean do
      description "Cancelled"
      default false
    end

    attribute :no_backorder, :boolean do
      description "No Backorder"
      default false
    end

    attribute :use_customer_item_number, :boolean do
      description "Use Customer Item Number"
      default false
    end

    attribute :freight_taxable1, :boolean do
      description "Freight Taxable 1"
      default false
    end

    attribute :freight_taxable2, :boolean do
      description "Freight Taxable 2"
      default false
    end

    attribute :apply_tax, :boolean do
      description "Apply Tax"
      default false
    end

    attribute :price_includes_tax, :boolean do
      description "Price Includes Tax"
      default false
    end

    attribute :order_printed, :boolean do
      description "Order Printed"
      default false
    end

    attribute :pick_list_printed, :boolean do
      description "Pick List Printed"
      default false
    end

    attribute :cod_tag_printed, :boolean do
      description "C.O.D. Tag Printed"
      default false
    end

    attribute :label_printed, :boolean do
      description "Label Printed"
      default false
    end

    attribute :save_credit_card, :boolean do
      description "Save Credit Card"
      default false
    end

    attribute :auto_accept_shipment, :boolean do
      description "Auto-accept Shipment"
      default false
    end

    # Numeric Fields
    attribute :discount_days, :integer do
      description "Terms Disc Days"
      default 0
    end

    attribute :due_days, :integer do
      description "Terms Net Days"
      default 0
    end

    attribute :term_discount_percent, :decimal do
      description "Terms Disc %"
      constraints precision: 6, scale: 2
      default 0
    end

    attribute :discount_rate, :decimal do
      description "Discount %"
      constraints precision: 6, scale: 2
      default 0
    end

    attribute :tax_version, :integer do
      description "Tax Version"
      default 0
    end

    attribute :freight_tax_version, :integer do
      description "Freight Tax Version"
      default 0
    end

    # Financial Amounts (Base Currency)
    attribute :taxable_amount1, :decimal do
      description "Taxable Amount 1"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :taxable_amount2, :decimal do
      description "Taxable Amount 2"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :sales_amount, :decimal do
      description "Subtotal Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :discount_amount, :decimal do
      description "Discount Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :freight_amount, :decimal do
      description "Freight Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :tax_amount1, :decimal do
      description "Tax Amount 1"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :tax_amount2, :decimal do
      description "Tax Amount 2"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :tax_amount3, :decimal do
      description "Tax Amount 3"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :freight_tax_amount1, :decimal do
      description "Freight Tax Amount 1"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :freight_tax_amount2, :decimal do
      description "Freight Tax Amount 2"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :freight_tax_amount3, :decimal do
      description "Freight Tax Amount 3"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :adjustment_amount, :decimal do
      description "Adjustment Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :adjusted_amount, :decimal do
      description "Adjusted Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :freight_amount_charged, :decimal do
      description "Freight Amount Charged"
      constraints precision: 18, scale: 4
      default 0
    end

    # Foreign Currency Amounts
    attribute :foreign_taxable_amount1, :decimal do
      description "Foreign Taxable Amount 1"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_taxable_amount2, :decimal do
      description "Foreign Taxable Amount 2"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_sales_amount, :decimal do
      description "Foreign Subtotal Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_discount_amount, :decimal do
      description "Foreign Discount Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_freight_amount, :decimal do
      description "Foreign Freight Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_tax_amount1, :decimal do
      description "Foreign Tax Amount 1"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_tax_amount2, :decimal do
      description "Foreign Tax Amount 2"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_tax_amount3, :decimal do
      description "Foreign Tax Amount 3"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_freight_tax_amount1, :decimal do
      description "Foreign Freight Tax Amount 1"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_freight_tax_amount2, :decimal do
      description "Foreign Freight Tax Amount 2"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_freight_tax_amount3, :decimal do
      description "Foreign Freight Tax Amount 3"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_adjustment_amount, :decimal do
      description "Foreign Adjustment Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_adjusted_amount, :decimal do
      description "Foreign Adjusted Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_freight_amount_charged, :decimal do
      description "Foreign Freight Amount Charged"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :weight, :decimal do
      description "Weight"
      constraints precision: 16, scale: 2
      default 0
    end

    attribute :exchange_rate, :decimal do
      description "Exchange Rate"
      constraints precision: 16, scale: 6
      default 1
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :line_items, AccountMate.SalesOrder.SalesOrderLineItem do
      destination_attribute :sales_order_id
    end

    has_many :remarks, AccountMate.SalesOrder.SalesOrderRemark do
      destination_attribute :sales_order_id
    end

    has_many :shipments, AccountMate.SalesOrder.Shipment do
      destination_attribute :sales_order_id
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Sales Order Line Item Table (Sostrs)
defmodule AccountMate.SalesOrder.SalesOrderLineItem do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :sales_order_id, :uuid do
      description "Sales Order ID"
      allow_nil? false
    end

    attribute :customer_number, :string do
      description "Customer Number"
      constraints max_length: 10
    end

    attribute :line_item_key, :string do
      description "Line Item Key"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :item_number, :string do
      description "Item Number"
      constraints max_length: 20
      allow_nil? false
    end

    attribute :specification_code1, :string do
      description "Specification Code 1"
      constraints max_length: 10
    end

    attribute :specification_code2, :string do
      description "Specification Code 2"
      constraints max_length: 10
    end

    attribute :description, :string do
      description "Item Description"
      constraints max_length: 54
      allow_nil? false
    end

    attribute :warehouse, :string do
      description "Warehouse"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :unit_of_measure, :string do
      description "Unit of Measure"
      constraints max_length: 10
    end

    attribute :commission, :string do
      description "Commission"
      constraints max_length: 10
    end

    attribute :revenue_code, :string do
      description "Revenue Code"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :tax_code, :string do
      description "Line Item Tax Code"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :request_date, :utc_datetime do
      description "Request Date"
    end

    # Boolean Flags
    attribute :kit_item, :boolean do
      description "Kit Item"
      default false
    end

    attribute :upsell_item, :boolean do
      description "Upsell Item"
      default false
    end

    attribute :stock_item, :boolean do
      description "Stock Item"
      default false
    end

    attribute :modified_kit_item, :boolean do
      description "Customized Kit Item"
      default false
    end

    attribute :taxable1, :boolean do
      description "Taxable 1"
      default false
    end

    attribute :taxable2, :boolean do
      description "Taxable 2"
      default false
    end

    attribute :overwrite_remark, :boolean do
      description "Overwrite Remark"
      default false
    end

    attribute :print_remark, :boolean do
      description "Print Remark"
      default false
    end

    attribute :print_remark_on_ar_packing_slip, :boolean do
      description "Print Remark on AR Packing Slip"
      default false
    end

    attribute :print_remark_on_so_pick_list, :boolean do
      description "Print Remark on SO Pick List"
      default false
    end

    attribute :print_remark_on_so_packing_slip, :boolean do
      description "Print Remark on SO Packing Slip"
      default false
    end

    attribute :auto_accept_shipment, :boolean do
      description "Auto-accept Shipment"
      default false
    end

    attribute :drop_ship, :boolean do
      description "Drop Ship"
      default false
    end

    attribute :calculate_price_from_components, :boolean do
      description "Calculate Price from Components"
      default false
    end

    # Numeric Fields
    attribute :quantity_decimal, :integer do
      description "Quantity Decimal"
      default 0
    end

    attribute :discount_rate, :decimal do
      description "Discount %"
      constraints precision: 6, scale: 2
      default 0
    end

    attribute :tax_version, :integer do
      description "Line Item Tax Version"
      default 0
    end

    # Financial Amounts (Base Currency)
    attribute :sales_amount, :decimal do
      description "Subtotal Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :discount_amount, :decimal do
      description "Discount Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :tax_amount1, :decimal do
      description "Line Item Tax Amount 1"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :tax_amount2, :decimal do
      description "Line Item Tax Amount 2"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :tax_amount3, :decimal do
      description "Line Item Tax Amount 3"
      constraints precision: 18, scale: 4
      default 0
    end

    # Foreign Currency Amounts
    attribute :foreign_sales_amount, :decimal do
      description "Foreign Subtotal Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_discount_amount, :decimal do
      description "Foreign Discount Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_tax_amount1, :decimal do
      description "Foreign Line Item Tax Amount 1"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_tax_amount2, :decimal do
      description "Foreign Line Item Tax Amount 2"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_tax_amount3, :decimal do
      description "Foreign Line Item Tax Amount 3"
      constraints precision: 18, scale: 4
      default 0
    end

    # Quantities
    attribute :built_quantity, :decimal do
      description "Built Quantity"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :order_quantity, :decimal do
      description "Order Quantity"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :ship_quantity, :decimal do
      description "Ship Quantity"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :advanced_quantity, :decimal do
      description "Advanced Quantity"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :base_uom_factor, :decimal do
      description "Base U/M Factor"
      constraints precision: 16, scale: 4
      default 1
    end

    attribute :transaction_uom_factor, :decimal do
      description "Transaction U/M Factor"
      constraints precision: 16, scale: 4
      default 1
    end

    attribute :weight, :decimal do
      description "Weight"
      constraints precision: 16, scale: 2
      default 0
    end

    # Pricing
    attribute :unit_cost, :decimal do
      description "Unit Cost"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :unit_price, :decimal do
      description "Unit Price"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :unit_price_plus_tax, :decimal do
      description "Unit Price + Tax"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :foreign_unit_price, :decimal do
      description "Foreign Unit Price"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :foreign_unit_price_plus_tax, :decimal do
      description "Foreign Unit Price + Tax"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :sequence, :integer do
      description "Sequence"
      default 10
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :sales_order, AccountMate.SalesOrder.SalesOrder do
      source_attribute :sales_order_id
      destination_attribute :id
    end

    has_many :remarks, AccountMate.SalesOrder.SalesOrderLineItemRemark do
      destination_attribute :line_item_id
    end

    has_many :kit_components, AccountMate.SalesOrder.SalesOrderKitFormula do
      destination_attribute :line_item_id
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Sales Order Line Item Remark Table (Sotrmk)
defmodule AccountMate.SalesOrder.SalesOrderLineItemRemark do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :line_item_id, :uuid do
      description "Line Item ID"
      allow_nil? false
    end

    attribute :sales_order_number, :string do
      description "Sales Order Number"
      constraints max_length: 10
    end

    attribute :remark, :string do
      description "Remark"
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :line_item, AccountMate.SalesOrder.SalesOrderLineItem do
      source_attribute :line_item_id
      destination_attribute :id
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Sales Order Remark Table (Sosork)
defmodule AccountMate.SalesOrder.SalesOrderRemark do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :sales_order_id, :uuid do
      description "Sales Order ID"
      allow_nil? false
    end

    attribute :sales_order_number, :string do
      description "Sales Order Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :remark, :string do
      description "Sales Order Remark"
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :sales_order, AccountMate.SalesOrder.SalesOrder do
      source_attribute :sales_order_id
      destination_attribute :id
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Sales Order Kit Formula Table (Soskit)
defmodule AccountMate.SalesOrder.SalesOrderKitFormula do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :sales_order_number, :string do
      description "Sales Order Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :line_item_id, :uuid do
      description "Line Item ID"
      allow_nil? false
    end

    attribute :line_item_number, :string do
      description "Line Item Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :item_number, :string do
      description "Item Number"
      constraints max_length: 20
      allow_nil? false
    end

    attribute :specification_code1, :string do
      description "Specification Code 1"
      constraints max_length: 10
    end

    attribute :specification_code2, :string do
      description "Specification Code 2"
      constraints max_length: 10
    end

    attribute :description, :string do
      description "Item Description"
      constraints max_length: 54
      allow_nil? false
    end

    attribute :print_component, :boolean do
      description "Indicates whether the component will be printed on orders"
      default false
    end

    attribute :stock_item, :boolean do
      description "Stock Item"
      default false
    end

    attribute :sequence, :integer do
      description "Order Sequence"
      default 0
    end

    attribute :quantity, :decimal do
      description "Quantity"
      constraints precision: 16, scale: 4
      allow_nil? false
    end

    attribute :unit_cost, :decimal do
      description "Unit Cost"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :foreign_unit_price, :decimal do
      description "Foreign Unit Price"
      constraints precision: 16, scale: 4
      default 0
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :line_item, AccountMate.SalesOrder.SalesOrderLineItem do
      source_attribute :line_item_id
      destination_attribute :id
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Shipment Header Table (Soship)
defmodule AccountMate.SalesOrder.Shipment do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :shipment_number, :string do
      description "Shipment Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :sales_order_id, :uuid do
      description "Sales Order ID"
      allow_nil? false
    end

    attribute :sales_order_number, :string do
      description "Sales Order Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :customer_number, :string do
      description "Customer Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :warehouse, :string do
      description "Warehouse"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :ordered_by, :string do
      description "Ordered By"
      constraints max_length: 30
    end

    attribute :salesperson_number, :string do
      description "Salesperson Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :entered_by, :string do
      description "Entered By"
      constraints max_length: 30
      allow_nil? false
    end

    # Bill To Address Fields
    attribute :bill_to_address_number, :string do
      description "Bill To Address Number"
      constraints max_length: 10
    end

    attribute :bill_to_company, :string do
      description "Bill To Company"
      constraints max_length: 40
    end

    attribute :bill_to_address1, :string do
      description "Bill To Address 1"
      constraints max_length: 40
    end

    attribute :bill_to_address2, :string do
      description "Bill To Address 2"
      constraints max_length: 40
    end

    attribute :bill_to_city, :string do
      description "Bill To City"
      constraints max_length: 30
    end

    attribute :bill_to_state, :string do
      description "Bill To State"
      constraints max_length: 15
    end

    attribute :bill_to_zip, :string do
      description "Bill To Zip"
      constraints max_length: 10
    end

    attribute :bill_to_country, :string do
      description "Bill To Country"
      constraints max_length: 25
    end

    attribute :bill_to_phone, :string do
      description "Bill To Phone"
      constraints max_length: 20
    end

    attribute :bill_to_contact, :string do
      description "Bill To Contact"
      constraints max_length: 30
    end

    attribute :bill_to_email, :string do
      description "Bill To Email Address"
    end

    # Ship To Address Fields
    attribute :ship_to_address_number, :string do
      description "Ship To Address Number"
      constraints max_length: 10
    end

    attribute :ship_to_company, :string do
      description "Ship To Company"
      constraints max_length: 40
    end

    attribute :ship_to_address1, :string do
      description "Ship To Address 1"
      constraints max_length: 40
    end

    attribute :ship_to_address2, :string do
      description "Ship To Address 2"
      constraints max_length: 40
    end

    attribute :ship_to_city, :string do
      description "Ship To City"
      constraints max_length: 30
    end

    attribute :ship_to_state, :string do
      description "Ship To State"
      constraints max_length: 15
    end

    attribute :ship_to_zip, :string do
      description "Ship To Zip"
      constraints max_length: 10
    end

    attribute :ship_to_country, :string do
      description "Ship To Country"
      constraints max_length: 25
    end

    attribute :ship_to_phone, :string do
      description "Ship To Phone"
      constraints max_length: 20
    end

    attribute :ship_to_contact, :string do
      description "Ship To Contact"
      constraints max_length: 30
    end

    attribute :ship_to_email, :string do
      description "Ship To Email Address"
    end

    # Shipping and Payment Info
    attribute :ship_via, :string do
      description "Ship Via"
      constraints max_length: 10
    end

    attribute :fob, :string do
      description "F.O.B."
      constraints max_length: 10
    end

    attribute :customer_po_number, :string do
      description "Customer PO Number"
      constraints max_length: 20
    end

    attribute :freight_code, :string do
      description "Freight Code"
      constraints max_length: 10
    end

    attribute :freight_tax_code, :string do
      description "Freight Sales Tax Code"
      constraints max_length: 10
    end

    attribute :tax_code, :string do
      description "Sales Tax Code"
      constraints max_length: 10
    end

    attribute :pay_code, :string do
      description "Pay Code"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :bank_number, :string do
      description "Bank Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :check_number, :string do
      description "Check Number"
      constraints max_length: 20
    end

    attribute :credit_card_number, :string do
      description "Credit Card Number"
      constraints max_length: 50
    end

    attribute :card_expiry_date, :string do
      description "Card Expiry Date"
      constraints max_length: 5
    end

    attribute :cardholder_name, :string do
      description "Cardholder Name"
      constraints max_length: 30
    end

    attribute :pay_reference, :string do
      description "Pay Reference"
      constraints max_length: 20
    end

    attribute :currency_code, :string do
      description "Currency Code"
      constraints max_length: 3
      allow_nil? false
    end

    attribute :ar_account, :string do
      description "Account Receivable GL Account ID"
      constraints max_length: 30
      allow_nil? false
    end

    attribute :commission, :string do
      description "Commission"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :source, :string do
      description "Source"
      constraints max_length: 10
      allow_nil? false
    end

    # Dates
    attribute :ship_date, :utc_datetime do
      description "Ship Date"
      allow_nil? false
    end

    attribute :order_date, :utc_datetime do
      description "Order Date"
      allow_nil? false
    end

    # Boolean Flags
    attribute :use_customer_item_number, :boolean do
      description "Use Customer Item Number"
      default false
    end

    attribute :freight_taxable1, :boolean do
      description "Freight Taxable 1"
      default false
    end

    attribute :freight_taxable2, :boolean do
      description "Freight Taxable 2"
      default false
    end

    attribute :apply_tax, :boolean do
      description "Apply Tax"
      default false
    end

    attribute :price_includes_tax, :boolean do
      description "Price Includes Tax"
      default false
    end

    attribute :slip_printed, :boolean do
      description "Slip Printed"
      default false
    end

    attribute :label_printed, :boolean do
      description "Label Printed"
      default false
    end

    # Numeric Fields
    attribute :tax_version, :integer do
      description "Tax Version"
      default 0
    end

    attribute :freight_tax_version, :integer do
      description "Freight Sales Tax Version"
      default 0
    end

    attribute :freight_amount, :decimal do
      description "Freight Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :adjustment_amount, :decimal do
      description "Adjustment Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :freight_tax_amount1, :decimal do
      description "Freight Tax Amount 1"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :freight_tax_amount2, :decimal do
      description "Freight Tax Amount 2"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :freight_tax_amount3, :decimal do
      description "Freight Tax Amount 3"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_freight_amount, :decimal do
      description "Foreign Freight Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_adjustment_amount, :decimal do
      description "Foreign Adjustment Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_freight_tax_amount1, :decimal do
      description "Foreign Freight Tax Amount 1"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_freight_tax_amount2, :decimal do
      description "Foreign Freight Tax Amount 2"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_freight_tax_amount3, :decimal do
      description "Foreign Freight Tax Amount 3"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :weight, :decimal do
      description "Weight"
      constraints precision: 16, scale: 2
      default 0
    end

    attribute :exchange_rate, :decimal do
      description "Exchange Rate"
      constraints precision: 16, scale: 6
      default 1
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :sales_order, AccountMate.SalesOrder.SalesOrder do
      source_attribute :sales_order_id
      destination_attribute :id
    end

    has_many :line_items, AccountMate.SalesOrder.ShipmentLineItem do
      destination_attribute :shipment_id
    end

    has_many :remarks, AccountMate.SalesOrder.ShipmentRemark do
      destination_attribute :shipment_id
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Shipment Line Item Table (Sosptr)
defmodule AccountMate.SalesOrder.ShipmentLineItem do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :shipment_id, :uuid do
      description "Shipment ID"
      allow_nil? false
    end

    attribute :shipment_number, :string do
      description "Shipment Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :sales_order_number, :string do
      description "Sales Order Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :sales_order_line_item_key, :string do
      description "Sales Order Line Item Key"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :item_number, :string do
      description "Item Number"
      constraints max_length: 20
      allow_nil? false
    end

    attribute :description, :string do
      description "Description"
      constraints max_length: 54
      allow_nil? false
    end

    attribute :specification_code1, :string do
      description "Specification Code 1"
      constraints max_length: 10
    end

    attribute :specification_code2, :string do
      description "Specification Code 2"
      constraints max_length: 10
    end

    attribute :line_item_key, :string do
      description "Line Item Key"
      constraints max_length: 10
    end

    attribute :invoice_number, :string do
      description "Invoice Number"
      constraints max_length: 10
    end

    attribute :customer_number, :string do
      description "Customer Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :warehouse, :string do
      description "Warehouse"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :bin, :string do
      description "Bin"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :unit_of_measure, :string do
      description "Unit of Measure"
      constraints max_length: 10
    end

    attribute :commission, :string do
      description "Commission"
      constraints max_length: 10
    end

    attribute :revenue_code, :string do
      description "Revenue Code"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :tax_code, :string do
      description "Line Item Tax Code"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :posted_to_gl, :string do
      description "Posted to GL"
      constraints max_length: 1
      allow_nil? false
    end

    attribute :ship_date, :utc_datetime do
      description "Ship Date"
      allow_nil? false
    end

    # Boolean Flags
    attribute :kit_item, :boolean do
      description "Kit Item"
      default false
    end

    attribute :stock_item, :boolean do
      description "Stock Item"
      default false
    end

    attribute :modified_kit_item, :boolean do
      description "Customized Kit Item"
      default false
    end

    attribute :multiple_bin, :boolean do
      description "Multiple Bin"
      default false
    end

    attribute :taxable1, :boolean do
      description "Taxable 1"
      default false
    end

    attribute :taxable2, :boolean do
      description "Taxable 2"
      default false
    end

    attribute :overwrite_remark, :boolean do
      description "Overwrite Remark"
      default false
    end

    attribute :print_remark, :boolean do
      description "Print Remark"
      default false
    end

    attribute :print_remark_on_ar_packing_slip, :boolean do
      description "Print Remark on AR Packing Slip"
      default false
    end

    attribute :print_remark_on_so_pick_list, :boolean do
      description "Print Remark on SO Pick List"
      default false
    end

    attribute :print_remark_on_so_packing_slip, :boolean do
      description "Print Remark on SO Packing Slip"
      default false
    end

    attribute :auto_accept_shipment, :boolean do
      description "Auto-accept Shipment"
      default false
    end

    attribute :drop_ship, :boolean do
      description "Drop Ship"
      default false
    end

    attribute :calculate_price_from_components, :boolean do
      description "Calculate Price from Components"
      default false
    end

    # Numeric Fields
    attribute :quantity_decimal, :integer do
      description "Quantity Decimal"
      default 0
    end

    attribute :discount_rate, :decimal do
      description "Discount %"
      constraints precision: 6, scale: 2
      default 0
    end

    attribute :tax_version, :integer do
      description "Line Item Tax Version"
      default 0
    end

    # Financial Amounts (Base Currency)
    attribute :sales_amount, :decimal do
      description "Subtotal Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :discount_amount, :decimal do
      description "Discount Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :tax_amount1, :decimal do
      description "Line Item Tax Amount 1"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :tax_amount2, :decimal do
      description "Line Item Tax Amount 2"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :tax_amount3, :decimal do
      description "Line Item Tax Amount 3"
      constraints precision: 18, scale: 4
      default 0
    end

    # Foreign Currency Amounts
    attribute :foreign_sales_amount, :decimal do
      description "Foreign Subtotal Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_discount_amount, :decimal do
      description "Foreign Discount Amount"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_tax_amount1, :decimal do
      description "Foreign Line Item Tax Amount 1"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_tax_amount2, :decimal do
      description "Foreign Line Item Tax Amount 2"
      constraints precision: 18, scale: 4
      default 0
    end

    attribute :foreign_tax_amount3, :decimal do
      description "Foreign Line Item Tax Amount 3"
      constraints precision: 18, scale: 4
      default 0
    end

    # Quantities
    attribute :ship_quantity, :decimal do
      description "Ship Quantity"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :cancel_quantity, :decimal do
      description "Cancel Quantity"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :base_uom_factor, :decimal do
      description "Base U/M Factor"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :transaction_uom_factor, :decimal do
      description "Transaction U/M Factor"
      constraints precision: 16, scale: 4
      default 0
    end

    # Pricing
    attribute :unit_cost, :decimal do
      description "Unit Cost"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :unit_price, :decimal do
      description "Unit Price"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :unit_price_plus_tax, :decimal do
      description "Unit Price + Tax"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :foreign_unit_price, :decimal do
      description "Foreign Unit Price"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :foreign_unit_price_plus_tax, :decimal do
      description "Foreign Unit Price + Tax"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :weight, :decimal do
      description "Weight"
      constraints precision: 16, scale: 2
      default 0
    end

    attribute :sequence, :integer do
      description "Sequence"
      default 0
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :shipment, AccountMate.SalesOrder.Shipment do
      source_attribute :shipment_id
      destination_attribute :id
    end

    has_many :remarks, AccountMate.SalesOrder.ShipmentLineItemRemark do
      destination_attribute :line_item_id
    end

    has_many :specifications, AccountMate.SalesOrder.ShipmentLineItemSpecification do
      destination_attribute :line_item_id
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Shipment Line Item Remark Table (Sosptk)
defmodule AccountMate.SalesOrder.ShipmentLineItemRemark do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :line_item_id, :uuid do
      description "Line Item ID"
      allow_nil? false
    end

    attribute :remark, :string do
      description "Remark"
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :line_item, AccountMate.SalesOrder.ShipmentLineItem do
      source_attribute :line_item_id
      destination_attribute :id
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Shipment Remark Table (Sosprk)
defmodule AccountMate.SalesOrder.ShipmentRemark do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :shipment_id, :uuid do
      description "Shipment ID"
      allow_nil? false
    end

    attribute :shipment_number, :string do
      description "Shipment Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :remark, :string do
      description "Remark"
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :shipment, AccountMate.SalesOrder.Shipment do
      source_attribute :shipment_id
      destination_attribute :id
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Shipment Line Item Specification Table (Sospsp)
defmodule AccountMate.SalesOrder.ShipmentLineItemSpecification do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id

    attribute :line_item_id, :uuid do
      description "Line Item ID"
      allow_nil? false
    end

    attribute :shipment_number, :string do
      description "Shipment Number"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :line_item_key, :string do
      description "Line Item Key"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :item_number, :string do
      description "Item Number"
      constraints max_length: 20
      allow_nil? false
    end

    attribute :inventory_specification_uid, :string do
      description "Inventory Specification Unique ID"
      constraints max_length: 15
    end

    attribute :serial_number, :string do
      description "Serial Number"
      constraints max_length: 30
      allow_nil? false
    end

    attribute :kit_number, :string do
      description "Kit Number"
      constraints max_length: 15
      allow_nil? false
    end

    attribute :lot_number, :string do
      description "Lot Number"
      constraints max_length: 15
      allow_nil? false
    end

    attribute :bin, :string do
      description "Bin"
      constraints max_length: 10
      allow_nil? false
    end

    attribute :ship_quantity, :decimal do
      description "Ship Quantity"
      constraints precision: 16, scale: 4
      default 0
    end

    attribute :unit_cost, :decimal do
      description "Unit Cost"
      constraints precision: 16, scale: 4
      default 0
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :line_item, AccountMate.SalesOrder.ShipmentLineItem do
      source_attribute :line_item_id
      destination_attribute :id
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
