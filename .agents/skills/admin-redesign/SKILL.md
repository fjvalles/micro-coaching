---
name: admin-redesign
description: Custom native Rails admin panel design system, layouts, reusable components, and controllers for Piloto Automático. Use when modifying the custom admin interface.
---

# Native Admin Redesign & Design System — Piloto Automático

This skill governs the project's native Rails admin panel. It describes the design system, components, controller conventions, and layouts.

## Design System & Tokens (`app/assets/stylesheets/admin.css`)

Our design system is built using modern CSS variables to ensure high cohesion, responsive design, and smooth interactions.

### Colors & Palette
- **Primary / Brand**: Deep royal indigo (`--brand: #6366f1; --brand-hover: #4f46e5;`)
- **Neutral Dark**: Zinc/Slate theme (`--bg-primary: #ffffff; --bg-secondary: #f8fafc; --text-main: #0f172a; --text-muted: #64748b;`)
- **Success / Active**: Emerald (`--emerald-500: #10b981; --emerald-50: #ecfdf5;`)
- **Warning / Pending**: Amber (`--amber-500: #f59e0b; --amber-50: #fffbeb;`)
- **Danger / Paused / Error**: Rose/Red (`--rose-500: #f43f5e; --rose-50: #fff1f2;`)
- **Borders & Shadows**: Soft gray borders (`--border-color: #e2e8f0;`) and modern cards shadows (`--shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05); --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1);`).

### Reusable CSS Components

1. **Sidebar Layout (`.admin-layout`)**
   A grid/flex container layout with a persistent left sidebar and a flexible content main container.
   ```css
   .admin-layout { display: flex; min-height: 100vh; }
   .admin-sidebar { width: 280px; flex-shrink: 0; background: #0f172a; color: #f8fafc; }
   .admin-main { flex-grow: 1; display: flex; flex-direction: column; background: #f8fafc; }
   ```

2. **Cards (`.card`)**
   Elevated, rounded corners (`12px`) and subtle borders with transitions.
   ```css
   .card { background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: 12px; box-shadow: var(--shadow-sm); transition: transform 0.2s, box-shadow 0.2s; }
   .card:hover { box-shadow: var(--shadow-md); }
   ```

3. **Tables (`.table`)**
   Clean alignments, padding, and subtle zebra stripes.
   ```css
   .table { width: 100%; border-collapse: collapse; text-align: left; }
   .table th { padding: 12px 16px; font-weight: 600; color: var(--text-muted); border-bottom: 2px solid var(--border-color); }
   .table td { padding: 16px; border-bottom: 1px solid var(--border-color); vertical-align: middle; }
   ```

4. **Badges (`.badge`)**
   Used for statuses (pending, active, completed, paused).
   - `.badge-success` (Green)
   - `.badge-warning` (Amber)
   - `.badge-danger` (Red)
   - `.badge-info` (Blue)

5. **Buttons (`.btn`)**
   Pill/rounded, focus states, interactive hover transitions:
   - `.btn-primary` (Indigo background, white text)
   - `.btn-secondary` (White background, gray border, dark text)
   - `.btn-danger` (Red/Rose background, white text)

## Controllers & Conventions (`app/controllers/admin/`)

All custom admin controllers inherit from `Admin::BaseController`:
```ruby
module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :authenticate_admin_user!
  end
end
```

Every resource controller must implement RESTful actions and use bullet-checked preloading:
- `index`: List resource, support pagination and simple search.
- `show`: Detailed view + associations lists.
- `new` / `create`: Form for model creation.
- `edit` / `update`: Form for model modification.
- `destroy`: Devise-protected soft/hard delete.

## UI Views Architecture

- **Layout**: `app/views/layouts/admin.html.erb`
- **Dashboard**: `app/views/admin/dashboard/index.html.erb` (shows overall stats and quick shortcuts)
- **Forms**: Use standard Rails form builders styled with our design system classes.

## Reusable View Components

We provide unified, accessible components for filtering and searching in resource lists. These are handled via global event delegation in `admin.html.erb`.

### 1. Reusable Search Field (`app/views/shared/_search_field.html.erb`)
Can be rendered in `:header_actions` (recommended) or inline. Preserves debounce auto-submit logic on input.

```erb
<%= render "shared/search_field",
      id: "my-resource-search",
      value: params[:q],
      form_id: "my-filters-form",
      placeholder: "Buscar...",
      style_type: :header %>
```

- `id`: Unique DOM ID.
- `value`: Current search value.
- `form_id`: Associated filters `<form>` ID (for submitting values outside the form tag).
- `style_type`: `:header` (clean text input) or `:inline` (search-wrapper with magnifying glass icon).
- `auto_submit`: Toggles automatic submit after typing (defaults to `true`).

### 2. Reusable Filter Dropdown (`app/views/shared/_filter_dropdown.html.erb` layout)
A wrapper for dropdown menus with checkbox/radio options. Truncates selection text and shows counts (e.g. `Estado: Activo +2`).

```erb
<%= render layout: "shared/filter_dropdown", locals: {
      label: "Fase",
      selected_values: selected_phases,
      clear_url: filter_url.call(clear_query.call(:phases)),
      is_active: @filters[:phases].present?
    } do %>
  <% phase_options.each do |label, value| %>
    <label class="filter-option">
      <%= check_box_tag "phases[]", value, @filters[:phases].include?(value),
            form: "my-filters-form", data: { auto_submit_filter: true } %>
      <span><%= label %></span>
    </label>
  <% end %>
<% end %>
```

- `label`: Dropdown title.
- `selected_values`: Array of string representations of selected choices (to display preview/extra count).
- `clear_url`: URL that clears this specific query key.
- `is_active`: Boolean to toggle the highlight state on summary trigger.
- Inside the block, options should use class `.filter-option` and `data: { auto_submit_filter: true }` to submit immediately on selection.
