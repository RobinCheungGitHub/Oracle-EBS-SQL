/*************************************************************************/
/*                                                                       */
/*                       (c) 2010-2020 Enginatics GmbH                   */
/*                              www.enginatics.com                       */
/*                                                                       */
/*************************************************************************/
-- Report Name: GL Account Analysis
-- Description: Detail GL transaction report with one line per transaction including all segments and subledger data, with amounts in both transaction currency and ledger currency.

-- Excel Examle Output: https://www.enginatics.com/example/gl-account-analysis/
-- Library Link: https://www.enginatics.com/reports/gl-account-analysis/
-- Run Report: https://demo.enginatics.com/

select
gjh.period_name,
gl.name ledger,
(select gjsv.user_je_source_name from gl_je_sources_vl gjsv where gjh.je_source=gjsv.je_source_name) source_name,
(select gjcv.user_je_category_name from gl_je_categories_vl gjcv where gjh.je_category=gjcv.je_category_name) category_name,
gjb.name batch_name,
xxen_util.meaning(gjb.status,'MJE_BATCH_STATUS',101) batch_status,
gjh.posted_date,
gjh.status journal_status,
gjh.name journal_name,
gjh.description journal_description,
gjl.description line_description,
xxen_util.meaning(xal.accounting_class_code,'XLA_ACCOUNTING_CLASS',602) accounting_class_code,
xxen_util.meaning(gcc.account_type,'ACCOUNT_TYPE',0) account_type,
&segment_columns
nvl2(xal.gl_sl_link_id,xal.currency_code,gjh.currency_code) transaction_currency,
nvl2(xal.gl_sl_link_id,xal.entered_dr,gjl.entered_dr) entered_dr,
nvl2(xal.gl_sl_link_id,xal.entered_cr,gjl.entered_cr) entered_cr,
nvl(nvl2(xal.gl_sl_link_id,xal.entered_dr,gjl.entered_dr),0)-nvl(nvl2(xal.gl_sl_link_id,xal.entered_cr,gjl.entered_cr),0) entered_amount,
gl.currency_code ledger_currency,
nvl2(xal.gl_sl_link_id,xal.accounted_dr,gjl.accounted_dr) accounted_dr,
nvl2(xal.gl_sl_link_id,xal.accounted_cr,gjl.accounted_cr) accounted_cr,
nvl(nvl2(xal.gl_sl_link_id,xal.accounted_dr,gjl.accounted_dr),0)-nvl(nvl2(xal.gl_sl_link_id,xal.accounted_cr,gjl.accounted_cr),0) accounted_amount,
nvl(gjh.doc_sequence_value,xah.doc_sequence_value) doc_sequence_value,
(select xett.name from xla_event_types_tl xett where xte.application_id=xett.application_id and xte.entity_code=xett.entity_code and xe.event_type_code=xett.event_type_code and xett.language=userenv('lang')) event_type,
xal.currency_conversion_date,
(select gdct.user_conversion_type from gl_daily_conversion_types gdct where xal.currency_conversion_type=gdct.conversion_type) conversion_type,
xal.currency_conversion_rate,
xxen_util.meaning(gjh.actual_flag,'XLA_BALANCE_TYPE',602) balance_type,
(select gbv.budget_name from gl_budget_versions gbv where gjh.budget_version_id=gbv.budget_version_id) budget_name,
gjh.currency_conversion_date,
gjh.currency_conversion_rate,
gjh.currency_conversion_type,
xe.transaction_date,
xte.transaction_number,
--subledger columns 
aia.description description,
(select pha.segment1 from po_headers_all pha where nvl(aia.quick_po_header_id,rt.po_header_id)=pha.po_header_id) purchase_order,
case when xte.entity_code='TRANSACTIONS' and rcta.interface_header_context in ('ORDER ENTRY','INTERCOMPANY') then rcta.interface_header_attribute1 end sales_order,
--AR
(select name from ra_rules rr where rcta.invoicing_rule_id=rule_id) invoice_rule,
(select rr.name from ra_customer_trx_lines_all rctla, ra_rules rr where rcta.customer_trx_id=rctla.customer_trx_id and rctla.line_type='LINE' and rctla.accounting_rule_id=rr.rule_id and rownum=1) accounting_rule,
rt.quantity po_quantity,
coalesce(
(select asu.vendor_name from ap_suppliers asu where coalesce(aia.vendor_id,aca.vendor_id,rt.vendor_id)=asu.vendor_id),
(select hp.party_name from hz_cust_accounts hca, hz_parties hp where coalesce(rcta.bill_to_customer_id,acra.pay_from_customer,paa.customer_id)=hca.cust_account_id and hca.party_id=hp.party_id)
) vendor_or_customer,
--Projects
coalesce(
(select ppa.segment1 from pa_projects_all ppa where aida.project_id=ppa.project_id),
case when xte.entity_code='TRANSACTIONS' and rcta.interface_header_context='PROJECTS INVOICES' then rcta.interface_header_attribute1 end,
ppa.segment1
) project,
pt.task_number task,
pea.expenditure_group,
xxen_util.meaning(pea.expenditure_class_code,'EXPENDITURE CLASS CODE',275) expenditure_class_code,
xxen_util.meaning(pea.expenditure_status_code,'EXPENDITURE STATUS',275) expenditure_status_code,
pet.expenditure_category,
peia.expenditure_type,
pet.description expenditure_type_description,
peia.expenditure_item_date,
peia.quantity expenditure_item_quantity,
xxen_util.meaning(pet.unit_of_measure,'UNIT',275) expenditure_unit_of_measure,
papf.full_name incurred_by_person,
nvl(papf.employee_number,papf.npw_number) incurred_by_employee_number,
gjb.je_batch_id,
gjl.je_header_id,
gjl.je_line_num,
gjl.context dff_context,
xal.application_id,
xal.ae_header_id,
xal.ae_line_num,
xah.event_id,
xe.event_date,
xte.entity_code,
xte.source_id_int_1
from
gl_ledgers gl,
gl_periods gp,
gl_je_batches gjb,
gl_je_headers gjh,
gl_je_lines gjl,
gl_import_references gir,
xla_ae_lines xal,
xla_ae_headers xah,
xla_events xe,
xla.xla_transaction_entities xte,
gl_code_combinations gcc,
ap_invoices_all aia,
(select distinct aida.invoice_id, min(aida.project_id) keep (dense_rank first order by aida.invoice_distribution_id) over (partition by aida.invoice_id) project_id, min(aida.task_id) keep (dense_rank first order by aida.invoice_distribution_id) over (partition by aida.invoice_id) task_id from ap_invoice_distributions_all aida where aida.task_id is not null) aida,
ap_checks_all aca,
ra_customer_trx_all rcta,
ar_adjustments_all aaa,
ar_cash_receipts_all acra,
pa_projects_all ppa,
pa_tasks pt,
pa_draft_revenues_all pdra,
pa_agreements_all paa,
pa_expenditure_items_all peia,
pa_expenditures_all pea,
pa_expenditure_types pet,
(select papf.* from per_all_people_f papf where sysdate>=papf.effective_start_date and sysdate<papf.effective_end_date+1) papf,
rcv_transactions rt
where
1=1 and
gl.period_set_name=gp.period_set_name and
gp.period_name=gjh.period_name and
gp.period_name=gjl.period_name and
gl.ledger_id=gjh.ledger_id and
gjb.je_batch_id=gjh.je_batch_id and
gjh.je_header_id=gjl.je_header_id and
gjl.je_header_id=gir.je_header_id(+) and
gjl.je_line_num=gir.je_line_num(+) and
gir.gl_sl_link_id=xal.gl_sl_link_id(+) and
gir.gl_sl_link_table=xal.gl_sl_link_table(+) and
xal.ae_header_id=xah.ae_header_id(+) and
xal.application_id=xah.application_id(+) and
xah.gl_transfer_status_code(+)='Y' and
xah.accounting_entry_status_code(+)='F' and
xah.event_id=xe.event_id(+) and
xah.application_id=xe.application_id(+) and
xah.entity_id=xte.entity_id(+) and
xah.application_id=xte.application_id(+) and
gjl.code_combination_id=gcc.code_combination_id and
case when xte.application_id=200 and xte.entity_code='AP_INVOICES' then xte.source_id_int_1 end=aia.invoice_id(+) and
aia.invoice_id=aida.invoice_id(+) and
case when xte.application_id=200 and xte.entity_code='AP_PAYMENTS' then xte.source_id_int_1 end=aca.check_id(+) and
case when xte.application_id=222 then case when xte.entity_code in ('TRANSACTIONS','BILLS_RECEIVABLE') then xte.source_id_int_1 when xte.entity_code='ADJUSTMENTS' then aaa.customer_trx_id end end=rcta.customer_trx_id(+) and
case when xte.application_id=222 and xte.entity_code='ADJUSTMENTS' then xte.source_id_int_1 end=aaa.adjustment_id(+) and
case when xte.application_id=222 and xte.entity_code='RECEIPTS' then xte.source_id_int_1 end=acra.cash_receipt_id(+) and
case when xte.application_id=275 then decode(xte.entity_code,'REVENUE',xte.source_id_int_1,'EXPENDITURES',peia.project_id) end=ppa.project_id(+) and
case when xte.application_id=275 and xte.entity_code='REVENUE' then xte.source_id_int_1 end=pdra.project_id(+) and
case when xte.application_id=275 and xte.entity_code='REVENUE' then xte.source_id_int_2 end=pdra.draft_revenue_num(+) and
pdra.agreement_id=paa.agreement_id(+) and
case when xte.application_id=275 and xte.entity_code='EXPENDITURES' then xte.source_id_int_1 end=peia.expenditure_item_id(+) and
nvl(aida.task_id,peia.task_id)=pt.task_id(+) and
peia.expenditure_id=pea.expenditure_id(+) and
peia.expenditure_type=pet.expenditure_type(+) and
pea.incurred_by_person_id=papf.person_id(+) and
case when xte.application_id=707 and xte.entity_code='RCV_ACCOUNTING_EVENTS' then xte.source_id_int_1 end=rt.transaction_id(+)