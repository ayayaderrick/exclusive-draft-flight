@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BookSuppl View Entity fro Draft RefScen'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZEFD_R_BOOKINGSUPPLEMENT_D
  as select from /dmo/a_bksuppl_d

  association        to parent ZEFD_R_BOOKING_D as _Booking        on $projection.BookingUuid = _Booking.BookingUuid

  association [1..1] to ZEFD_R_TRAVEL_D         as _Travel         on $projection.TravelUuid = _Travel.TravelUuid

  association [1..1] to /DMO/I_Supplement       as _Product        on $projection.SupplementId = _Product.SupplementID
  association [1..*] to /DMO/I_SupplementText   as _SupplementText on $projection.SupplementId = _SupplementText.SupplementID

{
  key booksuppl_uuid        as BooksupplUuid,
      root_uuid             as TravelUuid,
      parent_uuid           as BookingUuid,
      booking_supplement_id as BookingSupplementId,
      supplement_id         as SupplementId,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      price                 as Price,
      currency_code         as CurrencyCode,

      //local ETag field --> OData ETag
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      //Associations
      _Booking,
      _Travel,
      _Product,
      _SupplementText
}
