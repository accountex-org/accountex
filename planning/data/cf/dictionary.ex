defmodule AccountMate.CustomFields.CustomFieldDefinition do
  @moduledoc """
  Custom Field Definition Table (Cfflds)
  Defines custom fields that can be added to tables
  """
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "cfflds"
    repo AccountMate.Repo
  end

  attributes do
    attribute :ctable, :string do
      constraints max_length: 15
      description "Custom Table Name"
      allow_nil? false
    end

    attribute :cfield, :string do
      constraints max_length: 20
      description "Field Name"
      allow_nil? false
    end

    attribute :cfcaption, :string do
      constraints max_length: 50
      description "Field Caption"
      allow_nil? false
    end

    attribute :ctype, :string do
      constraints max_length: 20
      description "Data Type"
      allow_nil? false
    end

    attribute :cdefault, :string do
      constraints max_length: 250
      description "Default Value"
      allow_nil? true
    end

    attribute :cinputmask, :string do
      constraints max_length: 250
      description "Input Mask"
      allow_nil? true
    end

    attribute :clktype, :string do
      constraints max_length: 10
      description "Lookup Type"
      allow_nil? false
    end

    attribute :lnull, :integer do
      description "Nullable"
      default 0
    end

    attribute :llookup, :integer do
      description "Lookup"
      default 0
    end

    attribute :nlength, :integer do
      description "Field Length"
      allow_nil? false
    end

    attribute :ndecimal, :integer do
      description "Decimal"
      allow_nil? false
    end
  end

  identities do
    identity :unique_table_field, [:ctable, :cfield]
  end

  relationships do
    belongs_to :custom_field_master, AccountMate.CustomFields.CustomFieldMaster do
      source_attribute :ctable
      destination_attribute :ctable
    end

    belongs_to :lookup_type, AccountMate.CustomFields.CustomLookupType do
      source_attribute :clktype
      destination_attribute :ctype
    end
  end
end

defmodule AccountMate.CustomFields.CustomLookupType do
  @moduledoc """
  Custom Lookup Type Table (Cflktp)
  Defines types of lookups available for custom fields
  """
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "cflktp"
    repo AccountMate.Repo
  end

  attributes do
    attribute :ctype, :string do
      constraints max_length: 10
      description "Lookup type"
      allow_nil? false
    end

    attribute :cdescript, :string do
      constraints max_length: 35
      description "Description"
      allow_nil? false
    end

    attribute :lactive, :integer do
      description "Status"
      default 1
    end
  end

  identities do
    identity :unique_type, [:ctype]
  end

  relationships do
    has_many :lookup_codes, AccountMate.CustomFields.CustomLookupCode do
      source_attribute :ctype
      destination_attribute :ctype
    end

    has_many :field_definitions, AccountMate.CustomFields.CustomFieldDefinition do
      source_attribute :ctype
      destination_attribute :clktype
    end
  end
end

defmodule AccountMate.CustomFields.CustomLookupCode do
  @moduledoc """
  Custom Lookup Code Table (Cflkcd)
  Stores the actual lookup values for each lookup type
  """
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "cflkcd"
    repo AccountMate.Repo
  end

  attributes do
    attribute :ctype, :string do
      constraints max_length: 10
      description "Lookup Type"
      allow_nil? false
    end

    attribute :ccode, :string do
      constraints max_length: 10
      description "Lookup Code"
      allow_nil? false
    end

    attribute :cdescript, :string do
      constraints max_length: 35
      description "Description"
      allow_nil? false
    end

    attribute :lactive, :integer do
      description "Active"
      default 1
    end
  end

  identities do
    identity :unique_type_code, [:ctype, :ccode]
  end

  relationships do
    belongs_to :lookup_type, AccountMate.CustomFields.CustomLookupType do
      source_attribute :ctype
      destination_attribute :ctype
    end
  end
end

defmodule AccountMate.CustomFields.CustomFieldMaster do
  @moduledoc """
  Custom Field Master Table (Cftble)
  Defines which tables can have custom fields
  """
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "cftble"
    repo AccountMate.Repo
  end

  attributes do
    attribute :ctable, :string do
      constraints max_length: 15
      description "Table Name"
      allow_nil? false
    end

    attribute :cdescript, :string do
      constraints max_length: 50
      description "Description"
      allow_nil? false
    end

    attribute :cparent, :string do
      constraints max_length: 15
      description "Parent Table Name"
      allow_nil? true
    end

    attribute :cpkfield, :string do
      constraints max_length: 60
      description "Parent Primary Key Field"
      allow_nil? true
    end
  end

  identities do
    identity :unique_table, [:ctable]
  end

  relationships do
    has_many :field_definitions, AccountMate.CustomFields.CustomFieldDefinition do
      source_attribute :ctable
      destination_attribute :ctable
    end

    has_many :screen_customizations, AccountMate.CustomFields.ScreenCustomizationTable do
      source_attribute :ctable
      destination_attribute :ctable
    end
  end
end

defmodule AccountMate.CustomFields.ScreenCustomizationForm do
  @moduledoc """
  Screen Customization Form Table (Cfsfrm)
  Defines available screen forms for customization
  """
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "cfsfrm"
    repo AccountMate.Repo
  end

  attributes do
    attribute :cform, :string do
      constraints max_length: 50
      description "Screen Form"
      allow_nil? false
    end
  end

  identities do
    identity :unique_form, [:cform]
  end

  relationships do
    has_many :customization_pages, AccountMate.CustomFields.ScreenCustomizationPage do
      source_attribute :cform
      destination_attribute :cform
    end

    has_many :customization_fields, AccountMate.CustomFields.ScreenCustomizationField do
      source_attribute :cform
      destination_attribute :cform
    end

    has_many :customization_tables, AccountMate.CustomFields.ScreenCustomizationTable do
      source_attribute :cform
      destination_attribute :cform
    end
  end
end

defmodule AccountMate.CustomFields.ScreenCustomizationPage do
  @moduledoc """
  Screen Customization Page Table (Cfspge)
  Defines pages within screen forms for field organization
  """
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "cfspge"
    repo AccountMate.Repo
  end

  attributes do
    attribute :cform, :string do
      constraints max_length: 50
      description "Screen Form"
      allow_nil? false
    end

    attribute :cpagetab, :string do
      constraints max_length: 20
      description "Page Caption"
      allow_nil? false
    end

    attribute :npageno, :integer do
      description "Page #"
      allow_nil? false
    end
  end

  identities do
    identity :unique_form_page, [:cform, :npageno]
  end

  relationships do
    belongs_to :customization_form, AccountMate.CustomFields.ScreenCustomizationForm do
      source_attribute :cform
      destination_attribute :cform
    end

    has_many :customization_fields, AccountMate.CustomFields.ScreenCustomizationField do
      source_attribute :npageno
      destination_attribute :npageno
    end
  end
end

defmodule AccountMate.CustomFields.ScreenCustomizationField do
  @moduledoc """
  Screen Customization Field Table (Cfsfld)
  Links custom fields to specific forms and controls their display
  """
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "cfsfld"
    repo AccountMate.Repo
  end

  attributes do
    attribute :cform, :string do
      constraints max_length: 50
      description "Screen Form"
      allow_nil? false
    end

    attribute :ctable, :string do
      constraints max_length: 15
      description "Custom Table Name"
      allow_nil? false
    end

    attribute :cfield, :string do
      constraints max_length: 20
      description "Field Name"
      allow_nil? false
    end

    attribute :leditable, :integer do
      description "Editable"
      default 0
    end

    attribute :lshow, :integer do
      description "Show"
      default 0
    end

    attribute :nseq, :integer do
      description "Seq #"
      allow_nil? false
    end

    attribute :npageno, :integer do
      description "Page #"
      allow_nil? false
    end

    attribute :msetting, :string do
      description "Settings"
      allow_nil? true
    end
  end

  identities do
    identity :unique_form_table_field, [:cform, :ctable, :cfield]
  end

  relationships do
    belongs_to :customization_form, AccountMate.CustomFields.ScreenCustomizationForm do
      source_attribute :cform
      destination_attribute :cform
    end

    belongs_to :custom_field_master, AccountMate.CustomFields.CustomFieldMaster do
      source_attribute :ctable
      destination_attribute :ctable
    end

    belongs_to :field_definition, AccountMate.CustomFields.CustomFieldDefinition do
      source_attribute :cfield
      destination_attribute :cfield
    end

    belongs_to :customization_page, AccountMate.CustomFields.ScreenCustomizationPage do
      source_attribute :npageno
      destination_attribute :npageno
    end
  end
end

defmodule AccountMate.CustomFields.ScreenCustomizationTable do
  @moduledoc """
  Screen Customization Table Table (Cfstbl)
  Links tables to forms for customization
  """
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "cfstbl"
    repo AccountMate.Repo
  end

  attributes do
    attribute :ctable, :string do
      constraints max_length: 15
      description "Custom Table"
      allow_nil? false
    end

    attribute :cform, :string do
      constraints max_length: 50
      description "Screen Form"
      allow_nil? false
    end

    attribute :clinkfield, :string do
      constraints max_length: 60
      description "Linked Field"
      allow_nil? true
    end
  end

  identities do
    identity :unique_table_form, [:ctable, :cform]
  end

  relationships do
    belongs_to :custom_field_master, AccountMate.CustomFields.CustomFieldMaster do
      source_attribute :ctable
      destination_attribute :ctable
    end

    belongs_to :customization_form, AccountMate.CustomFields.ScreenCustomizationForm do
      source_attribute :cform
      destination_attribute :cform
    end
  end
end

defmodule AccountMate.CustomFields.CFSystem do
  @moduledoc """
  CF System Table (Cfsyst)
  System configuration for Custom Fields
  """
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "cfsyst"
    repo AccountMate.Repo
  end

  attributes do
    attribute :ccfsetup, :string do
      constraints max_length: 1
      description "CF Setup Status"
      allow_nil? false
    end

    attribute :cnewdbcver, :string do
      constraints max_length: 20
      description "New DBC Version"
      allow_nil? false
    end
  end
end

defmodule AccountMate.CustomFields.MiscellaneousCode do
  @moduledoc """
  Miscellaneous Code Table (Comisc)
  General purpose code table for various lookups
  """
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "comisc"
    repo AccountMate.Repo
  end

  attributes do
    attribute :ctype, :string do
      constraints max_length: 10
      description "Type"
      allow_nil? false
    end

    attribute :ccode, :string do
      constraints max_length: 10
      description "Code"
      allow_nil? false
    end

    attribute :cdescript, :string do
      constraints max_length: 35
      description "Description"
      allow_nil? false
    end

    attribute :cfdescript, :string do
      constraints max_length: 35
      description "Foreign Description"
      allow_nil? true
    end

    attribute :lactive, :integer do
      description "Active"
      default 1
    end
  end

  identities do
    identity :unique_type_code, [:ctype, :ccode]
  end
end

defmodule AccountMate.CustomFields.MiscellaneousCode2 do
  @moduledoc """
  Miscellaneous Code Table 2 (Comisc2)
  Extended miscellaneous code table with varchar code field
  """
  use Ash.Resource, data_layer: AshPostgres.DataLayer

  postgres do
    table "comisc2"
    repo AccountMate.Repo
  end

  attributes do
    attribute :ctype, :string do
      constraints max_length: 10
      description "Type"
      allow_nil? false
    end

    attribute :ccode, :string do
      description "Code"
      allow_nil? false
    end

    attribute :cdescript, :string do
      constraints max_length: 35
      description "Description"
      allow_nil? false
    end

    attribute :cfdescript, :string do
      constraints max_length: 35
      description "Foreign Description"
      allow_nil? true
    end

    attribute :lactive, :integer do
      description "Active"
      default 1
    end
  end

  identities do
    identity :unique_type_code, [:ctype, :ccode]
  end
end
