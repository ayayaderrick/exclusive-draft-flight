@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Booking View Entity for Draft RefScen'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZEFD_R_BOOKING_D
  as select from /dmo/a_booking_d as Booking


  association        to parent ZEFD_R_TRAVEL_D     as _Travel        on  $projection.TravelUuid = _Travel.TravelUuid
  composition [0..*] of ZEFD_R_BOOKINGSUPPLEMENT_D as _BookingSupplement

  association [1..1] to /DMO/I_Customer            as _Customer      on  $projection.CustomerId = _Customer.CustomerID
  association [1..1] to /DMO/I_Carrier             as _Carrier       on  $projection.AirlineId = _Carrier.AirlineID
  association [1..1] to /DMO/I_Connection          as _Connection    on  $projection.AirlineId    = _Connection.AirlineID
                                                                     and $projection.ConnectionId = _Connection.ConnectionID
  association [1..1] to /DMO/I_Booking_Status_VH   as _BookingStatus on  $projection.BookingStatus = _BookingStatus.BookingStatus

{
  key booking_uuid          as BookingUuid,
      parent_uuid           as TravelUuid,

      booking_id            as BookingId,
      booking_date          as BookingDate,
      customer_id           as CustomerId,
      carrier_id            as AirlineId,
      connection_id         as ConnectionId,
      flight_date           as FlightDate,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      flight_price          as FlightPrice,
      currency_code         as CurrencyCode,
      booking_status        as BookingStatus,

      //local ETag field --> OData ETag
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      // Associations
      _Travel,
      _BookingSupplement,
      _Customer,
      _Carrier,
      _Connection,
      _BookingStatus
}
