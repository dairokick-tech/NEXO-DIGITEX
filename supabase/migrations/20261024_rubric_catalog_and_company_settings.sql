-- NEXO DIGITEX: catálogo central de los 22 rubros y configuración por empresa.
-- Migración aditiva: no elimina ni modifica datos operativos.
-- Ejecutar primero en staging y revisar políticas RLS antes de habilitar acceso desde el cliente.

create table if not exists public.nexo_rubric_catalog (
  rubric_key text primary key,
  label text not null,
  description text not null default '',
  module_keys text[] not null default '{}',
  feature_spec jsonb not null default '{}'::jsonb,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.nexo_company_rubric_settings (
  company_id uuid primary key references public.nexo_companies(id) on delete restrict,
  rubric_key text not null references public.nexo_rubric_catalog(rubric_key) on update cascade on delete restrict,
  enabled_module_keys text[] not null default '{}',
  custom_settings jsonb not null default '{}'::jsonb,
  updated_by uuid,
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(custom_settings) = 'object')
);

create index if not exists idx_nexo_company_rubric_key on public.nexo_company_rubric_settings(rubric_key);

insert into public.nexo_rubric_catalog(rubric_key,label,description,module_keys,feature_spec) values
('farmacia','Farmacias y boticas','Medicamentos, lotes, vencimientos y trazabilidad',array['lector_barras','ventas','inventario','compras','clientes','caja','facturacion','farmacia_lotes','bodega_alertas'], '{"features":["lots","expiry_alerts","batch_traceability","restricted_product_controls","supplier_traceability","stock_by_batch"]}'),
('restaurante','Restaurantes y cafeterías','Mesas, comandas, recetas, insumos y delivery',array['lector_barras','ventas','inventario','compras','clientes','caja','restaurante','delivery','cotizaciones'], '{"features":["tables","kitchen_tickets","recipes","ingredient_deduction","takeaway","delivery","shift_close"]}'),
('agropecuaria','Agropecuarias','Insumos, semillas, lotes y trazabilidad',array['lector_barras','ventas','inventario','compras','clientes','caja','agro_lotes','agro_trazabilidad','cuentas_pagar'], '{"features":["field_lots","input_traceability","expiry","supplier_batches","units_of_measure"]}'),
('bodega','Bodegas y minimarkets','Ventas rápidas, caja y reposición',array['lector_barras','ventas','inventario','compras','clientes','caja','bodega_alertas','facturacion','tienda_online'], '{"features":["quick_pos","barcode","minimum_stock","cash_closing","promotions"]}'),
('tienda','Tiendas y comercios','Ventas, compras, clientes y sucursales',array['lector_barras','ventas','inventario','compras','clientes','caja','tienda_online','cotizaciones','devoluciones','sucursales','facturacion'], '{"features":["catalog","promotions","returns","multi_branch","price_lists"]}'),
('ropa','Tiendas de ropa y calzado','Variantes de talla, color, modelo y temporada',array['lector_barras','ventas','inventario','compras','clientes','caja','tienda_online','cotizaciones','devoluciones'], '{"features":["size_color_matrix","style_sku","seasonal_stock","exchange_returns","barcode_per_variant"]}'),
('ferreteria','Ferreterías','Materiales, medidas, herramientas y cotizaciones',array['lector_barras','ventas','inventario','compras','clientes','caja','cotizaciones','devoluciones','cuentas_pagar','sucursales'], '{"features":["multiple_units","unit_conversion","bulk_sales","quotations","stock_by_location"]}'),
('repuestos','Repuestos y accesorios','Piezas, compatibilidad y stock',array['lector_barras','ventas','inventario','compras','clientes','caja','cotizaciones','devoluciones','cuentas_pagar'], '{"features":["part_numbers","compatibility","serial_tracking","warranty","supplier_cross_reference"]}'),
('tecnologia','Electrónica y tecnología','Equipos, números de serie, garantías y accesorios',array['lector_barras','ventas','inventario','compras','clientes','caja','devoluciones','activos','tienda_online','facturacion'], '{"features":["serial_numbers","warranty_tracking","accessory_bundles","device_returns","asset_register"]}'),
('panaderia','Panaderías y pastelerías','Producción, recetas, insumos y mermas',array['lector_barras','ventas','inventario','compras','clientes','caja','rrhh','contabilidad','cotizaciones'], '{"features":["recipes","production_batches","ingredient_costing","waste_register","daily_production"]}'),
('salon_belleza','Salones de belleza','Citas, servicios, especialistas y cobros',array['lector_barras','ventas','clientes','caja','rrhh','belleza_agenda','cotizaciones'], '{"features":["appointments","staff_calendar","service_catalog","commissions","reminders"]}'),
('construccion','Materiales de construcción','Materiales, despacho, unidades y proyectos',array['lector_barras','ventas','inventario','compras','clientes','caja','delivery','cotizaciones','cuentas_pagar','sucursales'], '{"features":["project_quotations","bulk_units","dispatch","delivery_proof","project_costs"]}'),
('distribuidora','Mayoristas y distribuidores','Volúmenes, almacenes, rutas y liquidación de cobros',array['lector_barras','ventas','inventario','compras','clientes','caja','distribuidora_precios','distribuidora_rutas','distribuidora_cobros','delivery','sucursales'], '{"features":["tiered_pricing","sales_routes","driver_settlement","credit_collection","delivery_proof","fuel_expenses"]}'),
('veterinaria','Veterinarias','Productos veterinarios, pacientes y stock',array['lector_barras','ventas','inventario','compras','clientes','caja','cotizaciones'], '{"features":["animal_profiles","vaccination_records","product_expiry","appointments","patient_history"]}'),
('hotel','Hoteles y hospedajes','Reservas, habitaciones, servicios y cobros',array['lector_barras','ventas','clientes','caja','contabilidad','rrhh','cotizaciones'], '{"features":["room_inventory","reservations","check_in_out","service_charges","occupancy_reports"]}'),
('lavanderia','Lavanderías y servicios','Órdenes, prendas, entregas y pagos',array['lector_barras','ventas','clientes','caja','rrhh','cotizaciones'], '{"features":["service_orders","garment_tracking","delivery_receipts","due_dates","rework_incidents"]}'),
('servicios','Servicios y oficinas','Clientes, proyectos, cotizaciones, equipo y cobros',array['lector_barras','ventas','clientes','caja','contabilidad','rrhh','cotizaciones','facturacion','auditoria'], '{"features":["service_catalog","projects","work_orders","timesheets","approvals","document_templates"]}'),
('almacen','Almacenes y logística','Entradas, salidas, transferencias y kardex',array['lector_barras','inventario','compras','sucursales','cuentas_pagar','auditoria','distribuidora_rutas'], '{"features":["bin_locations","stock_transfers","cycle_counts","picking_packing","traceable_movements"]}'),
('taller','Talleres y servicios técnicos','Diagnóstico, órdenes de trabajo, repuestos y entrega',array['lector_barras','ventas','inventario','compras','clientes','caja','taller_ordenes','cotizaciones','devoluciones'], '{"features":["work_orders","diagnostics","labor_parts","approval_estimates","warranty","delivery_signoff"]}'),
('libreria','Librerías y útiles','Catálogo, códigos de barras y reposición',array['lector_barras','ventas','inventario','compras','clientes','caja','libreria_reposicion','tienda_online'], '{"features":["isbn","school_lists","bundles","reorder_suggestions","seasonal_demand"]}'),
('delivery','Distribución y delivery','Confirmación de entrega, cobros contra entrega y liquidación',array['lector_barras','ventas','clientes','caja','delivery','distribuidora_rutas'], '{"features":["proof_of_delivery","cash_on_delivery","driver_settlements","failed_delivery","returns","fuel_route_expenses","incidents","punctuality_reports"]}'),
('otro','Otros rubros','Categorías, campos, flujos y documentos configurables',array['lector_barras','ventas','inventario','compras','clientes','caja','contabilidad','rrhh','cotizaciones','facturacion'], '{"features":["custom_categories","custom_units","custom_fields","price_lists","custom_workflows","document_templates","custom_reports","optional_modules"]}')
on conflict (rubric_key) do update set label=excluded.label, description=excluded.description, module_keys=excluded.module_keys, feature_spec=excluded.feature_spec, updated_at=now();

-- No crear políticas permisivas automáticamente: vincular RLS al modelo real de membresías.
alter table public.nexo_rubric_catalog enable row level security;
alter table public.nexo_company_rubric_settings enable row level security;
