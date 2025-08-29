# Custom Field Manager Business Logic

## Overview

The Custom Field Manager application provides dynamic field extension capabilities for the Accountex system, allowing organizations to extend standard data models with custom fields, create custom lookup types, and customize screen layouts without modifying core application code.

## Core Concepts

### Custom Field
A user-defined field that extends a parent table/entity with additional data capture capabilities. Custom fields have specific data types, validation rules, and can be associated with lookup types for constrained value selection.

### Parent Table
An existing entity/resource in the system that can be extended with custom fields (e.g., Customer, Vendor, Invoice, etc.).

### Custom Table
A dynamically generated storage structure that holds custom field values for a specific parent table, linked via primary key relationships.

### Custom Lookup Type
A user-defined categorization for lookup values that can be used to validate custom field inputs.

### Custom Lookup Code
Individual values within a custom lookup type that serve as valid options for field selection.

### Screen Customization
The ability to add custom fields to specific screens/forms and control their layout, visibility, and editability.

## Commands

### Custom Field Definition Commands

#### CreateCustomField
Creates a new custom field definition for a parent table.

**Input:**
- parent_table_name (string, required)
- field_name (string, required, max 30 chars)
- field_caption (string, required, max 50 chars)
- data_type (enum: character, date, integer, logical, numeric, required)
- field_length (integer, required for character/numeric types)
- decimal_places (integer, required for numeric type)
- input_option (enum: uppercase_only, letters_only, alphanumeric, optional)
- default_value (varies by data_type, optional)
- allow_lookup (boolean, default false)
- lookup_type_code (string, required if allow_lookup is true)

**Validations:**
- Parent table must exist and be configured for custom fields
- Field name must be unique within the parent table's custom fields
- Field name must follow naming conventions (alphanumeric, underscore, no spaces)
- Data type constraints must be valid (length > 0, decimal_places <= field_length)
- If lookup is enabled, lookup_type must exist and be active
- System requires exclusive company access during creation

**Events:**
- CustomFieldCreated

#### UpdateCustomField
Updates an existing custom field definition.

**Input:**
- custom_field_id (uuid, required)
- field_caption (string, optional)
- default_value (varies by data_type, optional)
- allow_lookup (boolean, optional)
- lookup_type_code (string, required if allow_lookup changes to true)

**Validations:**
- Custom field must exist
- Cannot change field_name, data_type, or length if data exists
- Cannot disable lookup if field is used in active screen customizations
- System requires exclusive company access during update

**Events:**
- CustomFieldUpdated

#### DeleteCustomField
Removes a custom field definition.

**Input:**
- custom_field_id (uuid, required)

**Validations:**
- Custom field must exist
- No data must exist for this field
- Field must not be referenced in any screen customizations
- System requires exclusive company access during deletion

**Events:**
- CustomFieldDeleted

### Screen Customization Commands

#### AddCustomTableToScreen
Associates a custom table with a screen form.

**Input:**
- screen_form_name (string, required)
- custom_table_name (string, required)
- linked_fields (array of field mappings, required)

**Validations:**
- Screen form must exist and support customization
- Custom table must exist
- Linked fields must exist in both parent and custom tables
- No duplicate custom table associations for the same screen

**Events:**
- CustomTableAddedToScreen

#### ConfigureCustomFieldDisplay
Configures how a custom field appears on a screen.

**Input:**
- screen_form_name (string, required)
- custom_field_id (uuid, required)
- show_on_screen (boolean, required)
- is_editable (boolean, required)
- page_tab_name (string, optional)
- display_order (integer, optional)

**Validations:**
- Screen must have the custom table associated
- Custom field must belong to the associated custom table
- Page tab must exist if specified
- Display order must not conflict with existing fields

**Events:**
- CustomFieldDisplayConfigured

#### CreateScreenPageTab
Creates a new tab/page on a screen for organizing custom fields.

**Input:**
- screen_form_name (string, required)
- page_number (integer, required)
- page_caption (string, required, max 50 chars)

**Validations:**
- Screen must support customization
- Page number must be unique for the screen
- Caption must be unique for the screen

**Events:**
- ScreenPageTabCreated

#### UpdateScreenPageLayout
Updates the layout of custom fields on screen pages.

**Input:**
- screen_form_name (string, required)
- page_tab_name (string, required)
- custom_field_ids (array of uuid, required)
- field_positions (array of position objects, required)

**Validations:**
- All custom fields must be configured for display on the screen
- No overlapping field positions
- Fields must fit within page boundaries

**Events:**
- ScreenPageLayoutUpdated

### Custom Lookup Commands

#### CreateCustomLookupType
Creates a new lookup type for validating custom field values.

**Input:**
- lookup_type_code (string, required, max 10 chars)
- description (string, required, max 30 chars)
- is_active (boolean, default true)

**Validations:**
- Lookup type code must be unique
- Code must be alphanumeric with underscores only

**Events:**
- CustomLookupTypeCreated

#### UpdateCustomLookupType
Updates an existing lookup type.

**Input:**
- lookup_type_id (uuid, required)
- description (string, optional)
- is_active (boolean, optional)

**Validations:**
- Lookup type must exist
- Cannot deactivate if referenced by active custom fields

**Events:**
- CustomLookupTypeUpdated

#### CreateCustomLookupCode
Creates a lookup code within a lookup type.

**Input:**
- lookup_type_id (uuid, required)
- code (string, required, max 20 chars)
- description (string, required, max 50 chars)
- is_active (boolean, default true)

**Validations:**
- Lookup type must exist and be active
- Code must be unique within the lookup type

**Events:**
- CustomLookupCodeCreated

#### UpdateCustomLookupCode
Updates an existing lookup code.

**Input:**
- lookup_code_id (uuid, required)
- description (string, optional)
- is_active (boolean, optional)

**Validations:**
- Lookup code must exist
- Cannot deactivate if code is currently used in field values

**Events:**
- CustomLookupCodeUpdated

#### DeleteCustomLookupCode
Deletes a lookup code.

**Input:**
- lookup_code_id (uuid, required)

**Validations:**
- Lookup code must exist
- Code must not be referenced in any field values

**Events:**
- CustomLookupCodeDeleted

## Queries

### Custom Field Queries

#### GetCustomFieldsByParentTable
Retrieves all custom fields defined for a parent table.

**Input:**
- parent_table_name (string, required)
- include_inactive (boolean, default false)

**Output:**
- List of custom field definitions with full metadata

#### GetCustomFieldDefinition
Retrieves a specific custom field definition.

**Input:**
- custom_field_id (uuid, required)

**Output:**
- Complete custom field definition including data type, validations, and lookup configuration

#### GetCustomFieldLocations
Retrieves all screens where a custom field is used.

**Input:**
- custom_field_id (uuid, required)

**Output:**
- List of screen forms with display configuration for the field

### Screen Customization Queries

#### GetScreenCustomization
Retrieves complete customization configuration for a screen.

**Input:**
- screen_form_name (string, required)

**Output:**
- Custom tables associated with the screen
- Custom fields configuration
- Page tabs and layouts

#### GetAvailableParentTables
Retrieves list of tables that support custom fields.

**Output:**
- List of parent tables with their descriptions and primary keys

### Custom Lookup Queries

#### GetCustomLookupTypes
Retrieves all or filtered custom lookup types.

**Input:**
- is_active_only (boolean, default true)
- search_term (string, optional)

**Output:**
- List of lookup types with descriptions and status

#### GetCustomLookupCodes
Retrieves codes for a specific lookup type.

**Input:**
- lookup_type_id (uuid, required)
- is_active_only (boolean, default true)

**Output:**
- List of lookup codes with descriptions and status

#### ValidateLookupCode
Validates if a value is a valid code for a lookup type.

**Input:**
- lookup_type_id (uuid, required)
- code_value (string, required)

**Output:**
- is_valid (boolean)
- lookup_code_details (if valid)

## Events

### Custom Field Events

#### CustomFieldCreated
Emitted when a new custom field is defined.

**Payload:**
- custom_field_id
- parent_table_name
- field_name
- data_type
- created_by
- created_at

#### CustomFieldUpdated
Emitted when a custom field definition is modified.

**Payload:**
- custom_field_id
- changed_attributes (map of changed fields)
- updated_by
- updated_at

#### CustomFieldDeleted
Emitted when a custom field is removed.

**Payload:**
- custom_field_id
- parent_table_name
- deleted_by
- deleted_at

### Screen Customization Events

#### CustomTableAddedToScreen
Emitted when a custom table is associated with a screen.

**Payload:**
- screen_form_name
- custom_table_name
- linked_fields
- added_by
- added_at

#### CustomFieldDisplayConfigured
Emitted when field display settings are changed.

**Payload:**
- screen_form_name
- custom_field_id
- display_settings
- configured_by
- configured_at

#### ScreenPageTabCreated
Emitted when a new page tab is added to a screen.

**Payload:**
- screen_form_name
- page_number
- page_caption
- created_by
- created_at

### Lookup Events

#### CustomLookupTypeCreated
Emitted when a new lookup type is created.

**Payload:**
- lookup_type_id
- lookup_type_code
- description
- created_by
- created_at

#### CustomLookupCodeCreated
Emitted when a new lookup code is added.

**Payload:**
- lookup_code_id
- lookup_type_id
- code
- description
- created_by
- created_at

## Business Rules

### Field Definition Rules

1. **Data Type Constraints**
   - Character fields: length 1-255
   - Numeric fields: precision 1-18, scale 0-9
   - Integer fields: no decimal places allowed
   - Date fields: must support system date format
   - Logical fields: true/false only

2. **Naming Conventions**
   - Field names must start with a letter
   - Only alphanumeric and underscore characters allowed
   - Cannot use reserved system field names
   - Maximum 30 characters for field names

3. **Default Value Rules**
   - Must match the field's data type
   - For lookup fields, must be a valid lookup code
   - Date defaults can use system variables (TODAY, MONTH_START, etc.)

### Screen Customization Rules

1. **Field Visibility**
   - Required system fields cannot be hidden
   - Custom fields marked as required must be visible
   - Hidden fields cannot be marked as editable

2. **Page Tab Management**
   - At least one tab must exist if custom fields are displayed
   - Cannot delete a tab that contains fields
   - Tab order must be sequential without gaps

3. **Field Positioning**
   - Fields cannot overlap on the same page
   - Field width must respect data type constraints
   - Maintain minimum spacing between fields

### Lookup Management Rules

1. **Type Lifecycle**
   - Cannot delete lookup types referenced by custom fields
   - Deactivating a type prevents new field associations
   - Existing field values remain valid for inactive types

2. **Code Management**
   - Codes must be unique within a lookup type
   - Deactivated codes cannot be selected for new values
   - Historical data retains references to deleted codes

3. **Referential Integrity**
   - Maintain audit trail of lookup changes
   - Cascade status changes appropriately
   - Prevent orphaned references

## Integration Points

### With Core System

1. **Entity Extension**
   - Register custom tables with entity manager
   - Maintain referential integrity with parent tables
   - Synchronize field values during entity operations

2. **Query Enhancement**
   - Inject custom fields into entity queries
   - Support filtering and sorting on custom fields
   - Include custom fields in search operations

3. **Validation Framework**
   - Register custom field validators
   - Execute validation rules during data entry
   - Provide validation error messages

### With Other Applications

1. **Reporting Application**
   - Expose custom fields for report design
   - Provide field metadata for report builders
   - Support custom field aggregations

2. **Import/Export Application**
   - Include custom fields in data templates
   - Validate custom field data during import
   - Map external fields to custom fields

3. **Audit Application**
   - Track custom field value changes
   - Log field definition modifications
   - Record screen customization changes

4. **Security Application**
   - Apply field-level security to custom fields
   - Control access to customization features
   - Manage exclusive access for schema changes

## Performance Considerations

1. **Caching Strategy**
   - Cache field definitions per parent table
   - Cache lookup values with TTL
   - Cache screen customizations per user role

2. **Query Optimization**
   - Create indexes on custom field foreign keys
   - Optimize joins between parent and custom tables
   - Use materialized views for frequently accessed combinations

3. **Bulk Operations**
   - Batch custom field value updates
   - Provide bulk import for lookup codes
   - Support mass field assignment to screens

## Data Migration

1. **Field Migration**
   - Support copying field definitions between environments
   - Preserve field IDs for data consistency
   - Handle data type conversions safely

2. **Lookup Migration**
   - Export/import lookup types with codes
   - Maintain code relationships during migration
   - Validate lookup integrity post-migration

3. **Screen Migration**
   - Transfer screen customizations between systems
   - Adapt to screen version differences
   - Preserve user preferences where possible

## Error Handling

1. **Validation Errors**
   - Provide clear field validation messages
   - Highlight invalid fields on screen
   - Suggest valid values for lookup fields

2. **System Errors**
   - Handle exclusive access conflicts gracefully
   - Recover from partial customization updates
   - Log all customization failures for audit

3. **Data Integrity Errors**
   - Detect orphaned custom field values
   - Identify missing lookup references
   - Provide data cleanup utilities
