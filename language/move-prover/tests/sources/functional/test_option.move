module 0x42::test_option {

    use std::option::{Self, Option};

    spec add_option_u64 {
        ensures option::is_some(old(integer_opt)) ==>
            (option::borrow(integer_opt) ==  option::borrow(old(integer_opt)) + value);
    }

    fun add_option_u64(integer_opt: &mut Option<u64>, value: u64) {
        if (option::is_some(integer_opt)) {
            let integer = option::borrow_mut(integer_opt);
            *integer = *integer + value;
        }
    }

}
