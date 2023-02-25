module 0x1::aggregator {

    spec module {
        pragma verify = true;
    }

    /// Represents an integer which supports parallel additions and subtractions
    /// across multiple transactions. See the module description for more details.
    struct Aggregator has store {
        handle: address,
        key: address,
        limit: u128,
    }

    spec Aggregator {
        pragma intrinsic;
    }

    /// Returns `limit` exceeding which aggregator overflows.
    public fun limit(aggregator: &Aggregator): u128 {
        aggregator.limit
    }

    /// Adds `value` to aggregator. Aborts on overflowing the limit.
    public native fun add(aggregator: &mut Aggregator, value: u128);

    /// Subtracts `value` from aggregator. Aborts on going below zero.
    public native fun sub(aggregator: &mut Aggregator, value: u128);

    /// Returns a value stored in this aggregator.
    public native fun read(aggregator: &Aggregator): u128;

    /// Destroys an aggregator and removes it from its `AggregatorFactory`.
    public native fun destroy(aggregator: Aggregator);

    spec add {
        pragma opaque;
        aborts_if [abstract] spec_aggregator_get_val(aggregator) + value > spec_get_limit(aggregator);
        aborts_if [abstract] spec_aggregator_get_val(aggregator) + value > MAX_U128;
        ensures spec_get_limit(aggregator) == spec_get_limit(old(aggregator));
        ensures spec_aggregator_get_val(aggregator) == spec_aggregator_get_val(old(aggregator)) + value;
        ensures aggregator == spec_aggregator_set_val(old(aggregator),
            spec_aggregator_get_val(old(aggregator)) + value);
    }

    spec sub(aggregator: &mut Aggregator, value: u128) {
        pragma opaque;
        aborts_if [abstract] spec_aggregator_get_val(aggregator) < value;
        ensures spec_get_limit(aggregator) == spec_get_limit(old(aggregator));
        ensures spec_aggregator_get_val(aggregator) == spec_aggregator_get_val(old(aggregator)) - value;
        ensures aggregator == spec_aggregator_set_val(old(aggregator),
            spec_aggregator_get_val(old(aggregator)) - value);
    }

    spec read(aggregator: &Aggregator): u128 {
        pragma opaque;
        aborts_if false;
        ensures result == spec_read(aggregator);
        ensures result <= spec_get_limit(aggregator);
    }

    spec destroy(aggregator: Aggregator) {
        pragma opaque;
        aborts_if false;
    }

    spec native fun spec_read(aggregator: Aggregator): u128;
    spec native fun spec_get_limit(a: Aggregator): u128;
    spec native fun spec_get_handle(a: Aggregator): u128;
    spec native fun spec_get_key(a: Aggregator): u128;
    spec native fun spec_aggregator_set_val(a: Aggregator, v: u128): Aggregator;
    spec native fun spec_aggregator_get_val(a: Aggregator): u128;

}

module 0x1::aggregator_factory {
    use std::error;

    use 0x1::aggregator::Aggregator;
    use extensions::table::Table;
    use 0x1::aggregator;

    friend 0x1::optional_aggregator;

    /// Aggregator factory is not published yet.
    const EAGGREGATOR_FACTORY_NOT_FOUND: u64 = 1;

    /// Creates new aggregators. Used to control the numbers of aggregators in the
    /// system and who can create them. At the moment, only Aptos Framework (0x1)
    /// account can.
    struct AggregatorFactory has key {
        phantom_table: Table<address, u128>,
    }

    spec AggregatorFactory {
        pragma intrinsic;
    }

    /// Creates a new aggregator instance which overflows on exceeding a `limit`.
    public(friend) fun create_aggregator_internal(limit: u128): Aggregator acquires AggregatorFactory {
        assert!(
            exists<AggregatorFactory>(@0x1),
            error::not_found(EAGGREGATOR_FACTORY_NOT_FOUND)
        );
        let aggregator_factory = borrow_global_mut<AggregatorFactory>(@0x1);
        new_aggregator(aggregator_factory, limit)
    }

    spec create_aggregator_internal(limit: u128): Aggregator {
        include CreateAggregatorInternalAbortsIf;
        ensures aggregator::spec_get_limit(result) == limit;
        ensures aggregator::spec_aggregator_get_val(result) == 0;
    }
    spec schema CreateAggregatorInternalAbortsIf {
        aborts_if !exists<AggregatorFactory>(@0x1);
    }

    /// Returns a new aggregator.
    native fun new_aggregator(aggregator_factory: &mut AggregatorFactory, limit: u128): Aggregator;

    spec native fun spec_new_aggregator(limit: u128): Aggregator;

    spec new_aggregator(aggregator_factory: &mut AggregatorFactory, limit: u128): Aggregator {
        pragma opaque;
        aborts_if false;
        ensures result == spec_new_aggregator(limit);
        ensures aggregator::spec_get_limit(result) == limit;
    }


}


module 0x1::optional_aggregator {
    use std::error;
    use std::option::{Self, Option};

    use 0x1::aggregator_factory;
    use 0x1::aggregator::{Self, Aggregator};

    /// The value of aggregator underflows (goes below zero). Raised by native code.
    const EAGGREGATOR_OVERFLOW: u64 = 1;

    /// Aggregator feature is not supported. Raised by native code.
    const EAGGREGATOR_UNDERFLOW: u64 = 2;

    spec module {
        pragma aborts_if_is_strict;
    }

    /// Wrapper around integer with a custom overflow limit. Supports add, subtract and read just like `Aggregator`.
    struct Integer has store {
        value: u128,
        limit: u128,
    }

    /// Creates a new integer which overflows on exceeding a `limit`.
    fun new_integer(limit: u128): Integer {
        Integer {
            value: 0,
            limit,
        }
    }

    spec new_integer {
        aborts_if false;
        ensures result.limit == limit;
        ensures result.value == 0;
    }

    /// Adds `value` to integer. Aborts on overflowing the limit.
    fun add_integer(integer: &mut Integer, value: u128) {
        assert!(
            value <= (integer.limit - integer.value),
            error::out_of_range(EAGGREGATOR_OVERFLOW)
        );
        integer.value = integer.value + value;
    }

    spec add_integer {
        aborts_if value > (integer.limit - integer.value);
        aborts_if integer.value + value > MAX_U128;
        invariant integer.value <= integer.limit;
        ensures integer.value == old(integer.value) + value;
    }

    /// Subtracts `value` from integer. Aborts on going below zero.
    fun sub_integer(integer: &mut Integer, value: u128) {
        assert!(value <= integer.value, error::out_of_range(EAGGREGATOR_UNDERFLOW));
        integer.value = integer.value - value;
    }

    spec sub_integer {
        aborts_if value > integer.value;
        ensures integer.value == old(integer.value) - value;
    }

    /// Returns an overflow limit of integer.
    fun limit(integer: &Integer): u128 {
        integer.limit
    }

    /// Returns a value stored in this integer.
    fun read_integer(integer: &Integer): u128 {
        integer.value
    }

    /// Destroys an integer.
    fun destroy_integer(integer: Integer) {
        let Integer { value: _, limit: _ } = integer;
    }

    /// Contains either an aggregator or a normal integer, both overflowing on limit.
    struct OptionalAggregator has store {
        // Parallelizable.
        aggregator: Option<Aggregator>,
        // Non-parallelizable.
        integer: Option<Integer>,
    }

    spec OptionalAggregator {
        invariant option::is_some(aggregator) ==> option::is_none(integer);
        invariant option::is_some(integer) ==> option::is_none(aggregator);
        invariant option::is_none(aggregator) ==> option::is_some(integer);
        invariant option::is_none(integer) ==> option::is_some(aggregator);
        invariant option::is_some(integer) ==> option::borrow(integer).value <= option::borrow(integer).limit;
        invariant option::is_some(aggregator) ==> aggregator::spec_aggregator_get_val(option::borrow(aggregator)) <=
            aggregator::spec_get_limit(option::borrow(aggregator));
    }

    /// Creates a new optional aggregator.
    public(friend) fun new(limit: u128, parallelizable: bool): OptionalAggregator {
        if (parallelizable) {
            OptionalAggregator {
                aggregator: option::some(aggregator_factory::create_aggregator_internal(limit)),
                integer: option::none(),
            }
        } else {
            OptionalAggregator {
                aggregator: option::none(),
                integer: option::some(new_integer(limit)),
            }
        }
    }

    spec new {
        aborts_if parallelizable && !exists<aggregator_factory::AggregatorFactory>(@0x1);
        ensures parallelizable ==> is_parallelizable(result);
        ensures !parallelizable ==> !is_parallelizable(result);
        ensures optional_aggregator_value(result) == 0;
        ensures optional_aggregator_value(result) <= optional_aggregator_limit(result);
    }

    /// Switches between parallelizable and non-parallelizable implementations.
    public fun switch(optional_aggregator: &mut OptionalAggregator) {
        let value = read(optional_aggregator);
        switch_and_zero_out(optional_aggregator);
        add(optional_aggregator, value);
    }

    spec switch {
        let vec_ref = optional_aggregator.integer.vec;
        aborts_if is_parallelizable(optional_aggregator) && len(vec_ref) != 0;
        aborts_if !is_parallelizable(optional_aggregator) && len(vec_ref) == 0;
        aborts_if !is_parallelizable(optional_aggregator) && !exists<aggregator_factory::AggregatorFactory>(@0x1);
        let value = optional_aggregator_value(optional_aggregator);
        ensures optional_aggregator_value(optional_aggregator) == value;
    }

    spec fun optional_aggregator_value(optional_aggregator: OptionalAggregator): u128 {
        if (is_parallelizable(optional_aggregator)) {
            aggregator::spec_aggregator_get_val(option::borrow(optional_aggregator.aggregator))
        } else {
            option::borrow(optional_aggregator.integer).value
        }
    }

    spec fun optional_aggregator_limit(optional_aggregator: OptionalAggregator): u128 {
        if (is_parallelizable(optional_aggregator)) {
            aggregator::spec_get_limit(option::borrow(optional_aggregator.aggregator))
        } else {
            option::borrow(optional_aggregator.integer).limit
        }
    }

    /// Switches between parallelizable and non-parallelizable implementations, setting
    /// the value of the new optional aggregator to zero.
    fun switch_and_zero_out(optional_aggregator: &mut OptionalAggregator) {
        if (is_parallelizable(optional_aggregator)) {
            switch_to_integer_and_zero_out(optional_aggregator);
        } else {
            switch_to_aggregator_and_zero_out(optional_aggregator);
        }
    }

    spec switch_and_zero_out {
        let vec_ref = optional_aggregator.integer.vec;
        aborts_if is_parallelizable(optional_aggregator) && len(vec_ref) != 0;
        aborts_if !is_parallelizable(optional_aggregator) && len(vec_ref) == 0;
        aborts_if !is_parallelizable(optional_aggregator) && !exists<aggregator_factory::AggregatorFactory>(@0x1);
        ensures is_parallelizable(old(optional_aggregator)) ==> !is_parallelizable(optional_aggregator);
        ensures !is_parallelizable(old(optional_aggregator)) ==> is_parallelizable(optional_aggregator);
        ensures !is_parallelizable(optional_aggregator) ==> option::borrow(optional_aggregator.integer).value == 0;
        ensures is_parallelizable(optional_aggregator) ==> aggregator::spec_aggregator_get_val
            (option::borrow(optional_aggregator.aggregator)) == 0;
    }

    /// Switches from parallelizable to non-parallelizable implementation, zero-initializing
    /// the value.
    fun switch_to_integer_and_zero_out(
        optional_aggregator: &mut OptionalAggregator
    ): u128 {
        let aggregator = option::extract(&mut optional_aggregator.aggregator);
        let limit = aggregator::limit(&aggregator);
        aggregator::destroy(aggregator);
        let integer = new_integer(limit);
        option::fill(&mut optional_aggregator.integer, integer);
        limit
    }

    /// The aggregator exists and the integer dosex not exist when Switches from parallelizable to non-parallelizable implementation.
    spec switch_to_integer_and_zero_out {
        let limit = aggregator::spec_get_limit(option::borrow(optional_aggregator.aggregator));
        aborts_if len(optional_aggregator.aggregator.vec) == 0;
        aborts_if len(optional_aggregator.integer.vec) != 0;
        ensures !is_parallelizable(optional_aggregator);
        ensures option::borrow(optional_aggregator.integer).limit == limit;
        ensures option::borrow(optional_aggregator.integer).value == 0;
    }

    /// Switches from non-parallelizable to parallelizable implementation, zero-initializing
    /// the value.
    fun switch_to_aggregator_and_zero_out(
        optional_aggregator: &mut OptionalAggregator
    ): u128 {
        let integer = option::extract(&mut optional_aggregator.integer);
        let limit = limit(&integer);
        destroy_integer(integer);
        let aggregator = aggregator_factory::create_aggregator_internal(limit);
        option::fill(&mut optional_aggregator.aggregator, aggregator);
        limit
    }

    /// The integer exists and the aggregator does not exist when Switches from non-parallelizable to parallelizable implementation.
    /// The AggregatorFactory is under the @aptos_framework.
    spec switch_to_aggregator_and_zero_out {
        let limit = option::borrow(optional_aggregator.integer).limit;
        aborts_if len(optional_aggregator.integer.vec) == 0;
        aborts_if !exists<aggregator_factory::AggregatorFactory>(@0x1);
        aborts_if len(optional_aggregator.aggregator.vec) != 0;
        ensures is_parallelizable(optional_aggregator);
        ensures aggregator::spec_get_limit(option::borrow(optional_aggregator.aggregator)) == limit;
        ensures aggregator::spec_aggregator_get_val(option::borrow(optional_aggregator.aggregator)) == 0;
    }

    /// Destroys optional aggregator.
    public fun destroy(optional_aggregator: OptionalAggregator) {
        if (is_parallelizable(&optional_aggregator)) {
            destroy_optional_aggregator(optional_aggregator);
        } else {
            destroy_optional_integer(optional_aggregator);
        }
    }

    spec destroy {
        aborts_if is_parallelizable(optional_aggregator) && len(optional_aggregator.integer.vec) != 0;
        aborts_if !is_parallelizable(optional_aggregator) && len(optional_aggregator.integer.vec) == 0;
    }


    /// Destroys parallelizable optional aggregator and returns its limit.
    fun destroy_optional_aggregator(optional_aggregator: OptionalAggregator): u128 {
        let OptionalAggregator { aggregator, integer } = optional_aggregator;
        let limit = aggregator::limit(option::borrow(&aggregator));
        aggregator::destroy(option::destroy_some(aggregator));
        option::destroy_none(integer);
        limit
    }

    /// The aggregator exists and the integer does not exist when destroy the aggregator.
    spec destroy_optional_aggregator {
        aborts_if len(optional_aggregator.aggregator.vec) == 0;
        aborts_if len(optional_aggregator.integer.vec) != 0;
        ensures result == aggregator::spec_get_limit(option::borrow(optional_aggregator.aggregator));
    }

    /// Destroys non-parallelizable optional aggregator and returns its limit.
    fun destroy_optional_integer(optional_aggregator: OptionalAggregator): u128 {
        let OptionalAggregator { aggregator, integer } = optional_aggregator;
        let limit = limit(option::borrow(&integer));
        destroy_integer(option::destroy_some(integer));
        option::destroy_none(aggregator);
        limit
    }

    /// The integer exists and the aggregator does not exist when destroy the integer.
    spec destroy_optional_integer {
        aborts_if len(optional_aggregator.integer.vec) == 0;
        aborts_if len(optional_aggregator.aggregator.vec) != 0;
        ensures result == option::borrow(optional_aggregator.integer).limit;
    }

    /// Adds `value` to optional aggregator, aborting on exceeding the `limit`.
    public fun add(optional_aggregator: &mut OptionalAggregator, value: u128) {
        if (option::is_some(&optional_aggregator.aggregator)) {
            let aggregator = option::borrow_mut(&mut optional_aggregator.aggregator);
            aggregator::add(aggregator, value);
        } else {
            let integer = option::borrow_mut(&mut optional_aggregator.integer);
            assert!(
                value <= (integer.limit - integer.value),
                error::out_of_range(EAGGREGATOR_OVERFLOW)
            );
            add_integer(integer, value);
        }
    }

    spec add {
        aborts_if is_parallelizable(optional_aggregator) && (aggregator::spec_aggregator_get_val(option::borrow(optional_aggregator.aggregator))
            + value > aggregator::spec_get_limit(option::borrow(optional_aggregator.aggregator)));
        aborts_if is_parallelizable(optional_aggregator) && (aggregator::spec_aggregator_get_val(option::borrow(optional_aggregator.aggregator))
            + value > MAX_U128);
        aborts_if !is_parallelizable(optional_aggregator) &&
            (option::borrow(optional_aggregator.integer).value + value > MAX_U128);
        aborts_if !is_parallelizable(optional_aggregator) &&
            (value > (option::borrow(optional_aggregator.integer).limit - option::borrow(optional_aggregator.integer).value));
        ensures ((optional_aggregator_value(optional_aggregator) == optional_aggregator_value(old(optional_aggregator)) + value));
    }

    /// Subtracts `value` from optional aggregator, aborting on going below zero.
    public fun sub(optional_aggregator: &mut OptionalAggregator, value: u128) {
        if (option::is_some(&optional_aggregator.aggregator)) {
            let aggregator = option::borrow_mut(&mut optional_aggregator.aggregator);
            aggregator::sub(aggregator, value);
        } else {
            let integer = option::borrow_mut(&mut optional_aggregator.integer);
            sub_integer(integer, value);
        }
    }

    spec sub {
        aborts_if is_parallelizable(optional_aggregator) && (aggregator::spec_aggregator_get_val(option::borrow(optional_aggregator.aggregator))
            < value);
        aborts_if !is_parallelizable(optional_aggregator) &&
            (option::borrow(optional_aggregator.integer).value < value);
        ensures is_parallelizable(old(optional_aggregator)) ==> is_parallelizable(optional_aggregator);
        ensures !is_parallelizable(old(optional_aggregator)) ==> !is_parallelizable(optional_aggregator);
        ensures ((optional_aggregator_value(optional_aggregator) == optional_aggregator_value(old(optional_aggregator)) - value));
    }

    /// Returns the value stored in optional aggregator.
    public fun read(optional_aggregator: &OptionalAggregator): u128 {
        if (option::is_some(&optional_aggregator.aggregator)) {
            let aggregator = option::borrow(&optional_aggregator.aggregator);
            aggregator::read(aggregator)
        } else {
            let integer = option::borrow(&optional_aggregator.integer);
            read_integer(integer)
        }
    }

    spec read {
        ensures !is_parallelizable(optional_aggregator) ==> result == option::borrow(optional_aggregator.integer).value;
        ensures is_parallelizable(optional_aggregator) ==>
            result == aggregator::spec_read(option::borrow(optional_aggregator.aggregator));
    }

    /// Returns true if optional aggregator uses parallelizable implementation.
    public fun is_parallelizable(optional_aggregator: &OptionalAggregator): bool {
        option::is_some(&optional_aggregator.aggregator)
    }

}
