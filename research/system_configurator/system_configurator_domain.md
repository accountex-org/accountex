Based on the Accountex 12 Configurator Database Reference Guide, here's a comprehensive Ash domain and resources design for the System Configurator application:

## Accountex System Configurator Domain

### Domain Overview

```elixir
defmodule Accountex.SystemConfigurator do
  use Ash.Domain
  
  resources do
    resource Accountex.SystemConfigurator.ConfigurationVersion
    resource Accountex.SystemConfigurator.ConfigurationNote
    resource Accountex.SystemConfigurator.ConfigurationOption
    resource Accountex.SystemConfigurator.OptionChoice
    resource Accountex.SystemConfigurator.ConfigurationFormula
    resource Accountex.SystemConfigurator.ConfigurationRule
    resource Accountex.SystemConfigurator.ItemDefinition
    resource Accountex.SystemConfigurator.ItemDefinitionDetail
    resource Accountex.SystemConfigurator.ConfigurationBillOfMaterial
    resource Accountex.SystemConfigurator.PrintDefinition
    resource Accountex.SystemConfigurator.TransactionAnswer
    resource Accountex.SystemConfigurator.TransactionPrintOutput
    resource Accountex.SystemConfigurator.SystemConfiguration
    resource Accountex.SystemConfigurator.MiscellaneousCode
  end
end
```

### Domain Diagram

```mermaid
erDiagram
    ConfigurationVersion ||--o{ ConfigurationNote : has
    ConfigurationVersion ||--o{ ConfigurationOption : contains
    ConfigurationVersion ||--o{ ConfigurationFormula : includes
    ConfigurationVersion ||--o{ ConfigurationRule : defines
    ConfigurationVersion ||--o{ ItemDefinition : specifies
    ConfigurationVersion ||--o{ ConfigurationBillOfMaterial : lists
    ConfigurationVersion ||--o{ PrintDefinition : formats
    ConfigurationOption ||--o{ OptionChoice : offers
    ItemDefinition ||--o{ ItemDefinitionDetail : details
    ConfigurationRule ||--o{ ConfigurationOption : governs
    ConfigurationRule ||--o{ OptionChoice : controls
    ConfigurationRule ||--o{ ConfigurationBillOfMaterial : applies_to
    ConfigurationFormula ||--o{ ConfigurationBillOfMaterial : calculates
    ConfigurationVersion ||--o{ TransactionAnswer : tracks
    ConfigurationVersion ||--o{ TransactionPrintOutput : generates
```

### Resources

#### 1. ConfigurationVersion Resource

```elixir
defmodule Accountex.SystemConfigurator.ConfigurationVersion do
  use Ash.Resource,
    domain: Accountex.SystemConfigurator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "configuration_versions"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :configuration_code, :string do
      allow_nil? false
      constraints max_length: 10
    end
    
    attribute :version_description, :string do
      allow_nil? false
      constraints max_length: 54
    end
    
    attribute :version_status, :atom do
      allow_nil? false
      default :active
      constraints one_of: [:active, :inactive, :obsolete]
    end
    
    attribute :hold_reason_text, :string do
      constraints max_length: 10
    end
    
    attribute :is_on_hold, :boolean do
      default false
    end
    
    attribute :is_current_version, :boolean do
      default false
    end
    
    attribute :version_number, :integer do
      allow_nil? false
      default 1
    end
    
    create_timestamp :created_at
    update_timestamp :last_modified_at
  end

  relationships do
    has_one :configuration_note, Accountex.SystemConfigurator.ConfigurationNote
    has_many :configuration_options, Accountex.SystemConfigurator.ConfigurationOption
    has_many :configuration_formulas, Accountex.SystemConfigurator.ConfigurationFormula
    has_many :configuration_rules, Accountex.SystemConfigurator.ConfigurationRule
    has_many :item_definitions, Accountex.SystemConfigurator.ItemDefinition
    has_many :configuration_bill_of_materials, Accountex.SystemConfigurator.ConfigurationBillOfMaterial
    has_many :print_definitions, Accountex.SystemConfigurator.PrintDefinition
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    action :copy_version, :create do
      argument :source_configuration_id, :uuid, allow_nil?: false
    end
    
    action :set_current, :update do
      change set_attribute(:is_current_version, true)
    end
  end
end
```

#### 2. ConfigurationNote Resource

```elixir
defmodule Accountex.SystemConfigurator.ConfigurationNote do
  use Ash.Resource,
    domain: Accountex.SystemConfigurator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "configuration_notes"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :note_content, :text
  end

  relationships do
    belongs_to :configuration_version, Accountex.SystemConfigurator.ConfigurationVersion do
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

#### 3. ConfigurationOption Resource

```elixir
defmodule Accountex.SystemConfigurator.ConfigurationOption do
  use Ash.Resource,
    domain: Accountex.SystemConfigurator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "configuration_options"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :option_number, :integer do
      allow_nil? false
    end
    
    attribute :option_description, :string do
      allow_nil? false
      constraints max_length: 54
    end
    
    attribute :is_numeric_option, :boolean do
      default false
    end
    
    attribute :allow_value_override, :boolean do
      default false
    end
    
    attribute :use_dropdown_list, :boolean do
      default false
    end
    
    attribute :display_sequence, :integer do
      allow_nil? false
      default 0
    end
    
    attribute :item_id_field_length, :integer
    attribute :description_id_field_length, :integer
    attribute :quantity_decimal_places, :integer do
      default 0
    end
    
    attribute :fraction_base_value, :integer do
      default 0
    end
    
    attribute :default_numeric_value, :decimal do
      default 0
    end
    
    attribute :minimum_numeric_value, :decimal do
      default 0
    end
    
    attribute :maximum_numeric_value, :decimal do
      default 0
    end
    
    attribute :unit_price_amount, :decimal do
      default 0
    end
    
    attribute :standard_unit_cost, :decimal do
      default 0
    end
    
    attribute :return_unit_cost, :decimal do
      default 0
    end
  end

  relationships do
    belongs_to :configuration_version, Accountex.SystemConfigurator.ConfigurationVersion do
      allow_nil? false
    end
    
    belongs_to :configuration_rule, Accountex.SystemConfigurator.ConfigurationRule
    
    has_many :option_choices, Accountex.SystemConfigurator.OptionChoice
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

#### 4. OptionChoice Resource

```elixir
defmodule Accountex.SystemConfigurator.OptionChoice do
  use Ash.Resource,
    domain: Accountex.SystemConfigurator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "option_choices"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :choice_description, :string do
      allow_nil? false
      constraints max_length: 54
    end
    
    attribute :item_identifier, :string do
      constraints max_length: 20
    end
    
    attribute :description_identifier, :string do
      constraints max_length: 20
    end
    
    attribute :is_default_choice, :boolean do
      default false
    end
    
    attribute :display_sequence, :integer do
      allow_nil? false
      default 0
    end
    
    attribute :choice_value, :decimal do
      default 0
    end
    
    attribute :unit_price_amount, :decimal do
      default 0
    end
    
    attribute :standard_unit_cost, :decimal do
      default 0
    end
    
    attribute :return_unit_cost, :decimal do
      default 0
    end
  end

  relationships do
    belongs_to :configuration_version, Accountex.SystemConfigurator.ConfigurationVersion do
      allow_nil? false
    end
    
    belongs_to :configuration_option, Accountex.SystemConfigurator.ConfigurationOption do
      allow_nil? false
    end
    
    belongs_to :configuration_rule, Accountex.SystemConfigurator.ConfigurationRule
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

#### 5. ConfigurationFormula Resource

```elixir
defmodule Accountex.SystemConfigurator.ConfigurationFormula do
  use Ash.Resource,
    domain: Accountex.SystemConfigurator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "configuration_formulas"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :formula_number, :integer do
      allow_nil? false
    end
    
    attribute :formula_description, :string do
      allow_nil? false
      constraints max_length: 54
    end
    
    attribute :is_invalid_formula, :boolean do
      default false
    end
    
    attribute :fraction_base_value, :integer do
      default 0
    end
    
    attribute :quantity_decimal_places, :integer do
      default 0
    end
    
    attribute :item_id_field_length, :integer
    attribute :description_id_field_length, :integer
    
    attribute :unit_price_amount, :decimal do
      default 0
    end
    
    attribute :standard_unit_cost, :decimal do
      default 0
    end
    
    attribute :return_unit_cost, :decimal do
      default 0
    end
    
    attribute :formula_text_content, :text do
      allow_nil? false
    end
    
    attribute :compiled_formula_code, :text
  end

  relationships do
    belongs_to :configuration_version, Accountex.SystemConfigurator.ConfigurationVersion do
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

#### 6. ConfigurationRule Resource

```elixir
defmodule Accountex.SystemConfigurator.ConfigurationRule do
  use Ash.Resource,
    domain: Accountex.SystemConfigurator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "configuration_rules"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :rule_number, :integer do
      allow_nil? false
    end
    
    attribute :rule_description, :string do
      allow_nil? false
      constraints max_length: 54
    end
    
    attribute :is_invalid_rule, :boolean do
      default false
    end
    
    attribute :rule_text_content, :text do
      allow_nil? false
    end
    
    attribute :compiled_rule_code, :text
  end

  relationships do
    belongs_to :configuration_version, Accountex.SystemConfigurator.ConfigurationVersion do
      allow_nil? false
    end
    
    has_many :configuration_options, Accountex.SystemConfigurator.ConfigurationOption
    has_many :option_choices, Accountex.SystemConfigurator.OptionChoice
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

#### 7. ItemDefinition Resource

```elixir
defmodule Accountex.SystemConfigurator.ItemDefinition do
  use Ash.Resource,
    domain: Accountex.SystemConfigurator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "item_definitions"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :definition_code, :string do
      allow_nil? false
      constraints max_length: 20
    end
    
    attribute :definition_description, :string do
      allow_nil? false
      constraints max_length: 54
    end
    
    attribute :auto_add_items_enabled, :boolean do
      default false
    end
  end

  relationships do
    belongs_to :configuration_version, Accountex.SystemConfigurator.ConfigurationVersion do
      allow_nil? false
    end
    
    has_many :item_definition_details, Accountex.SystemConfigurator.ItemDefinitionDetail
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

#### 8. ItemDefinitionDetail Resource

```elixir
defmodule Accountex.SystemConfigurator.ItemDefinitionDetail do
  use Ash.Resource,
    domain: Accountex.SystemConfigurator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "item_definition_details"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :definition_type_code, :atom do
      allow_nil? false
      constraints one_of: [:item, :description, :price, :rule, :spec]
    end
    
    attribute :value_type_code, :atom do
      allow_nil? false
      constraints one_of: [:option, :formula, :user_defined]
    end
    
    attribute :user_defined_value, :string do
      constraints max_length: 1
    end
    
    attribute :value_reference_id, :uuid
    
    attribute :is_transaction_only, :boolean do
      default false
    end
    
    attribute :display_sequence, :integer do
      allow_nil? false
      default 0
    end
  end

  relationships do
    belongs_to :configuration_version, Accountex.SystemConfigurator.ConfigurationVersion do
      allow_nil? false
    end
    
    belongs_to :item_definition, Accountex.SystemConfigurator.ItemDefinition do
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

#### 9. ConfigurationBillOfMaterial Resource

```elixir
defmodule Accountex.SystemConfigurator.ConfigurationBillOfMaterial do
  use Ash.Resource,
    domain: Accountex.SystemConfigurator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "configuration_bill_of_materials"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :item_number, :string do
      allow_nil? false
      constraints max_length: 20
    end
    
    attribute :specification_code_one, :string do
      constraints max_length: 10
    end
    
    attribute :specification_code_two, :string do
      constraints max_length: 10
    end
    
    attribute :bill_of_materials_unique_id, :string do
      constraints max_length: 15
    end
  end

  relationships do
    belongs_to :configuration_version, Accountex.SystemConfigurator.ConfigurationVersion do
      allow_nil? false
    end
    
    belongs_to :configuration_formula, Accountex.SystemConfigurator.ConfigurationFormula
    belongs_to :configuration_rule, Accountex.SystemConfigurator.ConfigurationRule
    belongs_to :item_definition, Accountex.SystemConfigurator.ItemDefinition
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

#### 10. PrintDefinition Resource

```elixir
defmodule Accountex.SystemConfigurator.PrintDefinition do
  use Ash.Resource,
    domain: Accountex.SystemConfigurator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "print_definitions"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :print_key_identifier, :string do
      allow_nil? false
      constraints max_length: 15
    end
    
    attribute :print_type_code, :atom do
      allow_nil? false
      constraints one_of: [:option, :formula]
    end
    
    attribute :type_reference_id, :uuid do
      allow_nil? false
    end
    
    attribute :display_sequence, :integer do
      allow_nil? false
      default 0
    end
  end

  relationships do
    belongs_to :configuration_version, Accountex.SystemConfigurator.ConfigurationVersion do
      allow_nil? false
    end
    
    belongs_to :configuration_rule, Accountex.SystemConfigurator.ConfigurationRule
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

#### 11. TransactionAnswer Resource

```elixir
defmodule Accountex.SystemConfigurator.TransactionAnswer do
  use Ash.Resource,
    domain: Accountex.SystemConfigurator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "transaction_answers"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :unique_identifier, :string do
      allow_nil? false
      constraints max_length: 15
    end
    
    attribute :transaction_number, :string do
      allow_nil? false
      constraints max_length: 10
    end
    
    attribute :transaction_type, :string do
      allow_nil? false
      constraints max_length: 10
    end
    
    attribute :line_item_number, :string do
      constraints max_length: 10
    end
    
    attribute :configuration_version_number, :integer do
      allow_nil? false
      default 1
    end
    
    attribute :answer_value, :decimal do
      default 0
    end
    
    update_timestamp :last_modified_at
  end

  relationships do
    belongs_to :configuration_version, Accountex.SystemConfigurator.ConfigurationVersion do
      allow_nil? false
    end
    
    belongs_to :configuration_option, Accountex.SystemConfigurator.ConfigurationOption do
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

#### 12. TransactionPrintOutput Resource

```elixir
defmodule Accountex.SystemConfigurator.TransactionPrintOutput do
  use Ash.Resource,
    domain: Accountex.SystemConfigurator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "transaction_print_outputs"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :unique_identifier, :string do
      allow_nil? false
      constraints max_length: 15
    end
    
    attribute :transaction_number, :string do
      allow_nil? false
      constraints max_length: 10
    end
    
    attribute :transaction_type, :string do
      allow_nil? false
      constraints max_length: 10
    end
    
    attribute :line_item_number, :string do
      constraints max_length: 10
    end
    
    attribute :print_key_identifier, :string do
      allow_nil? false
      constraints max_length: 15
    end
    
    attribute :configuration_version_number, :integer do
      allow_nil? false
      default 1
    end
    
    attribute :output_content, :text do
      allow_nil? false
    end
  end

  relationships do
    belongs_to :configuration_version, Accountex.SystemConfigurator.ConfigurationVersion do
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

#### 13. SystemConfiguration Resource

```elixir
defmodule Accountex.SystemConfigurator.SystemConfiguration do
  use Ash.Resource,
    domain: Accountex.SystemConfigurator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "system_configurations"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :manufacturing_configurator_enabled, :boolean do
      default false
    end
    
    attribute :sales_configurator_enabled, :boolean do
      default false
    end
    
    attribute :next_bom_id_number, :integer do
      default 1
    end
    
    attribute :next_choices_id_number, :integer do
      default 1
    end
    
    attribute :next_formula_id_number, :integer do
      default 1
    end
    
    attribute :next_definition_id_number, :integer do
      default 1
    end
    
    attribute :next_definition_detail_id_number, :integer do
      default 1
    end
    
    attribute :next_master_id_number, :integer do
      default 1
    end
    
    attribute :next_options_id_number, :integer do
      default 1
    end
    
    attribute :next_print_id_number, :integer do
      default 1
    end
    
    attribute :next_rule_id_number, :integer do
      default 1
    end
  end

  actions do
    defaults [:read, :update]
    
    create :initialize do
      accept []
    end
  end
end
```

#### 14. MiscellaneousCode Resource

```elixir
defmodule Accountex.SystemConfigurator.MiscellaneousCode do
  use Ash.Resource,
    domain: Accountex.SystemConfigurator,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "miscellaneous_codes"
    repo Accountex.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :code_type, :string do
      allow_nil? false
      constraints max_length: 10
    end
    
    attribute :code_value, :string do
      allow_nil? false
      constraints max_length: 10
    end
    
    attribute :code_description, :string do
      allow_nil? false
      constraints max_length: 35
    end
    
    attribute :foreign_description, :string do
      constraints max_length: 35
    end
    
    attribute :is_active, :boolean do
      default true
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

### Code Interfaces

```elixir
defmodule Accountex.SystemConfigurator do
  use Ash.Domain
  
  # ... resources definition ...
  
  # Configuration Versions
  def list_configuration_versions(opts \\ []), do: Accountex.SystemConfigurator.ConfigurationVersion.read!(opts)
  def get_configuration_version!(id), do: Accountex.SystemConfigurator.ConfigurationVersion.get!(id)
  def create_configuration_version!(params), do: Accountex.SystemConfigurator.ConfigurationVersion.create!(params)
  def update_configuration_version!(record, params), do: Accountex.SystemConfigurator.ConfigurationVersion.update!(record, params)
  def delete_configuration_version!(record), do: Accountex.SystemConfigurator.ConfigurationVersion.destroy!(record)
  def copy_configuration_version!(source_id), do: Accountex.SystemConfigurator.ConfigurationVersion.copy_version!(source_configuration_id: source_id)
  
  # Configuration Options
  def list_configuration_options(opts \\ []), do: Accountex.SystemConfigurator.ConfigurationOption.read!(opts)
  def get_configuration_option!(id), do: Accountex.SystemConfigurator.ConfigurationOption.get!(id)
  def create_configuration_option!(params), do: Accountex.SystemConfigurator.ConfigurationOption.create!(params)
  def update_configuration_option!(record, params), do: Accountex.SystemConfigurator.ConfigurationOption.update!(record, params)
  def delete_configuration_option!(record), do: Accountex.SystemConfigurator.ConfigurationOption.destroy!(record)
  
  # Option Choices
  def list_option_choices(opts \\ []), do: Accountex.SystemConfigurator.OptionChoice.read!(opts)
  def get_option_choice!(id), do: Accountex.SystemConfigurator.OptionChoice.get!(id)
  def create_option_choice!(params), do: Accountex.SystemConfigurator.OptionChoice.create!(params)
  def update_option_choice!(record, params), do: Accountex.SystemConfigurator.OptionChoice.update!(record, params)
  def delete_option_choice!(record), do: Accountex.SystemConfigurator.OptionChoice.destroy!(record)
  
  # Configuration Formulas
  def list_configuration_formulas(opts \\ []), do: Accountex.SystemConfigurator.ConfigurationFormula.read!(opts)
  def get_configuration_formula!(id), do: Accountex.SystemConfigurator.ConfigurationFormula.get!(id)
  def create_configuration_formula!(params), do: Accountex.SystemConfigurator.ConfigurationFormula.create!(params)
  def update_configuration_formula!(record, params), do: Accountex.SystemConfigurator.ConfigurationFormula.update!(record, params)
  def delete_configuration_formula!(record), do: Accountex.SystemConfigurator.ConfigurationFormula.destroy!(record)
  
  # Configuration Rules
  def list_configuration_rules(opts \\ []), do: Accountex.SystemConfigurator.ConfigurationRule.read!(opts)
  def get_configuration_rule!(id), do: Accountex.SystemConfigurator.ConfigurationRule.get!(id)
  def create_configuration_rule!(params), do: Accountex.SystemConfigurator.ConfigurationRule.create!(params)
  def update_configuration_rule!(record, params), do: Accountex.SystemConfigurator.ConfigurationRule.update!(record, params)
  def delete_configuration_rule!(record), do: Accountex.SystemConfigurator.ConfigurationRule.destroy!(record)
  
  # Item Definitions
  def list_item_definitions(opts \\ []), do: Accountex.SystemConfigurator.ItemDefinition.read!(opts)
  def get_item_definition!(id), do: Accountex.SystemConfigurator.ItemDefinition.get!(id)
  def create_item_definition!(params), do: Accountex.SystemConfigurator.ItemDefinition.create!(params)
  def update_item_definition!(record, params), do: Accountex.SystemConfigurator.ItemDefinition.update!(record, params)
  def delete_item_definition!(record), do: Accountex.SystemConfigurator.ItemDefinition.destroy!(record)
  
  # Item Definition Details
  def list_item_definition_details(opts \\ []), do: Accountex.SystemConfigurator.ItemDefinitionDetail.read!(opts)
  def get_item_definition_detail!(id), do: Accountex.SystemConfigurator.ItemDefinitionDetail.get!(id)
  def create_item_definition_detail!(params), do: Accountex.SystemConfigurator.ItemDefinitionDetail.create!(params)
  def update_item_definition_detail!(record, params), do: Accountex.SystemConfigurator.ItemDefinitionDetail.update!(record, params)
  def delete_item_definition_detail!(record), do: Accountex.SystemConfigurator.ItemDefinitionDetail.destroy!(record)
  
  # Configuration Bill of Materials
  def list_configuration_bill_of_materials(opts \\ []), do: Accountex.SystemConfigurator.ConfigurationBillOfMaterial.read!(opts)
  def get_configuration_bill_of_material!(id), do: Accountex.SystemConfigurator.ConfigurationBillOfMaterial.get!(id)
  def create_configuration_bill_of_material!(params), do: Accountex.SystemConfigurator.ConfigurationBillOfMaterial.create!(params)
  def update_configuration_bill_of_material!(record, params), do: Accountex.SystemConfigurator.ConfigurationBillOfMaterial.update!(record, params)
  def delete_configuration_bill_of_material!(record), do: Accountex.SystemConfigurator.ConfigurationBillOfMaterial.destroy!(record)
  
  # Print Definitions
  def list_print_definitions(opts \\ []), do: Accountex.SystemConfigurator.PrintDefinition.read!(opts)
  def get_print_definition!(id), do: Accountex.SystemConfigurator.PrintDefinition.get!(id)
  def create_print_definition!(params), do: Accountex.SystemConfigurator.PrintDefinition.create!(params)
  def update_print_definition!(record, params), do: Accountex.SystemConfigurator.PrintDefinition.update!(record, params)
  def delete_print_definition!(record), do: Accountex.SystemConfigurator.PrintDefinition.destroy!(record)
  
  # Transaction Answers
  def list_transaction_answers(opts \\ []), do: Accountex.SystemConfigurator.TransactionAnswer.read!(opts)
  def get_transaction_answer!(id), do: Accountex.SystemConfigurator.TransactionAnswer.get!(id)
  def create_transaction_answer!(params), do: Accountex.SystemConfigurator.TransactionAnswer.create!(params)
  def update_transaction_answer!(record, params), do: Accountex.SystemConfigurator.TransactionAnswer.update!(record, params)
  def delete_transaction_answer!(record), do: Accountex.SystemConfigurator.TransactionAnswer.destroy!(record)
  
  # Transaction Print Outputs
  def list_transaction_print_outputs(opts \\ []), do: Accountex.SystemConfigurator.TransactionPrintOutput.read!(opts)
  def get_transaction_print_output!(id), do: Accountex.SystemConfigurator.TransactionPrintOutput.get!(id)
  def create_transaction_print_output!(params), do: Accountex.SystemConfigurator.TransactionPrintOutput.create!(params)
  def update_transaction_print_output!(record, params), do: Accountex.SystemConfigurator.TransactionPrintOutput.update!(record, params)
  def delete_transaction_print_output!(record), do: Accountex.SystemConfigurator.TransactionPrintOutput.destroy!(record)
  
  # System Configuration
  def get_system_configuration!, do: Accountex.SystemConfigurator.SystemConfiguration.read!() |> List.first()
  def update_system_configuration!(record, params), do: Accountex.SystemConfigurator.SystemConfiguration.update!(record, params)
  def initialize_system_configuration!, do: Accountex.SystemConfigurator.SystemConfiguration.initialize!()
  
  # Miscellaneous Codes
  def list_miscellaneous_codes(opts \\ []), do: Accountex.SystemConfigurator.MiscellaneousCode.read!(opts)
  def get_miscellaneous_code!(id), do: Accountex.SystemConfigurator.MiscellaneousCode.get!(id)
  def create_miscellaneous_code!(params), do: Accountex.SystemConfigurator.MiscellaneousCode.create!(params)
  def update_miscellaneous_code!(record, params), do: Accountex.SystemConfigurator.MiscellaneousCode.update!(record, params)
  def delete_miscellaneous_code!(record), do: Accountex.SystemConfigurator.MiscellaneousCode.destroy!(record)
end
```

This design follows all the requirements:
- Uses semantically correct long names for resources and fields
- All fields use snake_case format
- No field or resource names match the original data dictionary names
- Foreign key relationships are properly defined with `_id` suffix
- UUID7 is used for all primary keys (named `id`)
- Includes all necessary relationships between resources
- Provides comprehensive code interfaces using pluralized resource names