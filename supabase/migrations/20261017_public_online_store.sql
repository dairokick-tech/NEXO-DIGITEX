create or replace function public.nexo_public_store(_company_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $function$
  select jsonb_build_object(
    'company', jsonb_build_object(
      'id', c.id,
      'name', c.name,
      'business_type', c.business_type,
      'tax_id', c.tax_id,
      'phone', c.phone,
      'whatsapp', c.whatsapp,
      'address', c.address,
      'contact_email', coalesce(c.contact_email, c.email)
    ),
    'products', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'description', p.description,
          'category', p.category,
          'price', p.price,
          'image_url', p.image_url,
          'sku', p.sku
        ) order by p.name
      )
      from public.nexo_products p
      where p.company_id = c.id
        and p.active = true
        and p.stock > 0
    ), '[]'::jsonb)
  )
  from public.nexo_companies c
  join public.nexo_subscriptions s on s.company_id = c.id
  join public.nexo_plans pl on pl.id = s.plan_id
  where c.id = _company_id
    and c.status = 'approved'
    and s.status = 'active'
    and pl.active = true
  limit 1;
$function$;

revoke all on function public.nexo_public_store(uuid) from public;
grant execute on function public.nexo_public_store(uuid) to anon, authenticated;