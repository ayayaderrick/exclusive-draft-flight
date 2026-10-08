CLASS lhc_Travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF travel_status,
        open     TYPE c LENGTH 1 VALUE 'O', "Open
        accepted TYPE c LENGTH 1 VALUE 'A', "Accepted
        rejected TYPE c LENGTH 1 VALUE 'X', "Rejected
      END OF travel_status.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      keys REQUEST requested_authorizations FOR Travel RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR Travel RESULT result.

    METHODS acceptTravel FOR MODIFY
       keys FOR ACTION Travel~acceptTravel RESULT result.

    METHODS rejectTravel FOR MODIFY
       keys FOR ACTION Travel~rejectTravel RESULT result.
    METHODS GetDefaultsFordeductDiscount FOR READ
       keys FOR FUNCTION Travel~GetDefaultsFordeductDiscount RESULT result.
    METHODS deductDiscount FOR MODIFY
       keys FOR ACTION Travel~deductDiscount RESULT result.
    METHODS reCalcTotalPrice FOR MODIFY
      keys FOR ACTION Travel~reCalcTotalPrice.

ENDCLASS.

CLASS lhc_Travel IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD acceptTravel.

    "Modify travel instance
    MODIFY ENTITIES OF zefd_r_travel_d IN LOCAL MODE
      ENTITY Travel
        UPDATE FIELDS (  OverallStatus )
        WITH VALUE #( FOR key IN keys ( %tky          = key-%tky
                                        OverallStatus = travel_status-accepted ) ).

    "Read changed data for action result
    READ ENTITIES OF zefd_r_travel_d IN LOCAL MODE
      ENTITY Travel
        ALL FIELDS WITH
        CORRESPONDING #( keys )
      RESULT DATA(travels).

    result = VALUE #( FOR travel IN travels ( %tky   = travel-%tky
                                              %param = travel ) ).

  ENDMETHOD.

  METHOD rejectTravel.

    "Modify travel instance
    MODIFY ENTITIES OF zefd_r_travel_d IN LOCAL MODE
      ENTITY Travel
        UPDATE FIELDS (  OverallStatus )
        WITH VALUE #( FOR key IN keys ( %tky          = key-%tky
                                        OverallStatus = travel_status-rejected ) ).

    "Read changed data for action result
    READ ENTITIES OF zefd_r_travel_d IN LOCAL MODE
      ENTITY Travel
        ALL FIELDS WITH
        CORRESPONDING #( keys )
      RESULT DATA(travels).

    result = VALUE #( FOR travel IN travels ( %tky   = travel-%tky
                                              %param = travel ) ).

  ENDMETHOD.

  METHOD GetDefaultsFordeductDiscount.

    READ ENTITIES OF zefd_r_travel_d IN LOCAL MODE
      ENTITY Travel
        FIELDS ( TotalPrice )
        WITH CORRESPONDING #( keys )
      RESULT DATA(travels)
      FAILED failed.

    LOOP AT travels INTO DATA(travel).
      IF travel-TotalPrice >= 5000.
        APPEND VALUE #( %tky                     = travel-%tky
                        %param-discount_percent  = 20 ) TO result.
      ELSE.
        APPEND VALUE #( %tky                     = travel-%tky
                        %param-discount_percent  = 10 ) TO result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD deductDiscount.
    DATA travels_for_update TYPE TABLE FOR UPDATE zefd_r_travel_d.
    DATA(keys_with_valid_discount) = keys.

    LOOP AT keys_with_valid_discount ASSIGNING FIELD-SYMBOL(<key_with_valid_discount>) WHERE %param-discount_percent IS INITIAL
                                                        OR %param-discount_percent > 100
                                                        OR %param-discount_percent <= 0.

      APPEND VALUE #( %tky = <key_with_valid_discount>-%tky ) TO failed-travel.

      APPEND VALUE #( %tky = <key_with_valid_discount>-%tky
                      %msg = NEW /dmo/cm_flight_messages(
                                 textid = /dmo/cm_flight_messages=>discount_invalid
                                 severity = if_abap_behv_message=>severity-error )
                      %element-TotalPrice        = if_abap_behv=>mk-on
                      %op-%action-deductDiscount = if_abap_behv=>mk-on
                    ) TO reported-travel.

      DELETE keys_with_valid_discount.
    ENDLOOP.

    CHECK keys_with_valid_discount IS NOT INITIAL.

    "get total price
    READ ENTITIES OF zefd_r_travel_d IN LOCAL MODE
      ENTITY Travel
        FIELDS ( BookingFee )
        WITH CORRESPONDING #( keys_with_valid_discount )
      RESULT DATA(travels).

    LOOP AT travels ASSIGNING FIELD-SYMBOL(<travel>).
      DATA percentage TYPE decfloat16.
      DATA(discount_percent) = keys_with_valid_discount[ KEY id  %tky = <travel>-%tky ]-%param-discount_percent.
      percentage =  discount_percent / 100 .
      DATA(reduced_fee) = <travel>-BookingFee * ( 1 - percentage ) .

      APPEND VALUE #( %tky = <travel>-%tky
                      BookingFee = reduced_fee
                    ) TO travels_for_update.
    ENDLOOP.

    "update total price with reduced price
    MODIFY ENTITIES OF zefd_r_travel_d IN LOCAL MODE
      ENTITY Travel
       UPDATE FIELDS ( BookingFee )
       WITH travels_for_update.

    "Read changed data for action result
    READ ENTITIES OF zefd_r_travel_d IN LOCAL MODE
      ENTITY Travel
        ALL FIELDS WITH
        CORRESPONDING #( travels )
      RESULT DATA(travels_with_discount).

    result = VALUE #( FOR travel IN travels_with_discount ( %tky   = travel-%tky
                                                            %param = travel ) ).

  ENDMETHOD.

  METHOD reCalcTotalPrice.
      TYPES: BEGIN OF ty_amount_per_currencycode,
             amount        TYPE /dmo/total_price,
             currency_code TYPE /dmo/currency_code,
           END OF ty_amount_per_currencycode.

    DATA: amounts_per_currencycode TYPE STANDARD TABLE OF ty_amount_per_currencycode.

    " Read all relevant travel instances.
    READ ENTITIES OF zefd_r_travel_d IN LOCAL MODE
         ENTITY Travel
            FIELDS ( BookingFee CurrencyCode )
            WITH CORRESPONDING #( keys )
         RESULT DATA(travels).

    DELETE travels WHERE CurrencyCode IS INITIAL.

    " Read all associated bookings and add them to the total price.
    READ ENTITIES OF zefd_r_travel_d IN LOCAL MODE
      ENTITY Travel BY \_Booking
        FIELDS ( FlightPrice CurrencyCode )
      WITH CORRESPONDING #( travels )
      LINK DATA(booking_links)
      RESULT DATA(bookings).

    " Read all associated booking supplements and add them to the total price.
    READ ENTITIES OF zefd_r_travel_d IN LOCAL MODE
      ENTITY Booking BY \_BookingSupplement
        FIELDS ( BookSupplPrice CurrencyCode )
      WITH CORRESPONDING #( bookings )
      LINK DATA(bookingsupplement_links)
      RESULT DATA(bookingsupplements).

    LOOP AT travels ASSIGNING FIELD-SYMBOL(<travel>).
      " Set the start for the calculation by adding the booking fee.
      amounts_per_currencycode = VALUE #( ( amount        = <travel>-bookingfee
                                            currency_code = <travel>-currencycode ) ).

      LOOP AT booking_links INTO DATA(booking_link) USING KEY id WHERE source-%tky = <travel>-%tky.
        " Short dump occurs if link table does not match read table, which must never happen
        DATA(booking) = bookings[ KEY id  %tky = booking_link-target-%tky ].
        COLLECT VALUE ty_amount_per_currencycode( amount        = booking-flightprice
                                                  currency_code = booking-currencycode ) INTO amounts_per_currencycode.

        LOOP AT bookingsupplement_links INTO DATA(bookingsupplement_link) USING KEY id WHERE source-%tky = booking-%tky.
          DATA(bookingsupplement) = bookingsupplements[ KEY id  %tky = bookingsupplement_link-target-%tky ].
          COLLECT VALUE ty_amount_per_currencycode( amount        = bookingsupplement-booksupplprice
                                                    currency_code = bookingsupplement-currencycode ) INTO amounts_per_currencycode.
        ENDLOOP.
      ENDLOOP.

      DELETE amounts_per_currencycode WHERE currency_code IS INITIAL.

      CLEAR <travel>-TotalPrice.
      LOOP AT amounts_per_currencycode INTO DATA(amount_per_currencycode).
        " If needed do a Currency Conversion
        IF amount_per_currencycode-currency_code = <travel>-CurrencyCode.
          <travel>-TotalPrice += amount_per_currencycode-amount.
        ELSE.
          /dmo/cl_flight_amdp=>convert_currency(
             EXPORTING
               iv_amount                   =  amount_per_currencycode-amount
               iv_currency_code_source     =  amount_per_currencycode-currency_code
               iv_currency_code_target     =  <travel>-CurrencyCode
               iv_exchange_rate_date       =  cl_abap_context_info=>get_system_date( )
             IMPORTING
               ev_amount                   = DATA(total_booking_price_per_curr)
            ).
          <travel>-TotalPrice += total_booking_price_per_curr.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    " write back the modified total_price of travels
    MODIFY ENTITIES OF zefd_r_travel_d IN LOCAL MODE
      ENTITY travel
        UPDATE FIELDS ( TotalPrice )
        WITH CORRESPONDING #( travels ).

  ENDMETHOD.

ENDCLASS.
