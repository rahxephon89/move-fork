// Copyright (c) The Diem Core Contributors
// Copyright (c) The Move Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::{
    abi_signature::{from_event_sig, from_solidity_sig},
    context::Context,
};
use move_abi::abi_move_type::ABIMoveSignature;

use itertools::Itertools;
use move_core_types::metadata::Metadata;
use std::{collections::BTreeMap, str};

/// Address at which the EVM modules are stored.
const ABI_MOVE_KEY: &str = "abi_move";

/// Generate Metadata for move signature
pub(crate) fn generate_abi_move_metadata(ctx: &Context) -> Metadata {
    let mut event_map = BTreeMap::new();
    let event_sigs_keys = ctx
        .event_signature_map
        .borrow()
        .keys()
        .cloned()
        .collect_vec();
    for key in &event_sigs_keys {
        let st_env = ctx.env.get_struct(key.to_qualified_id());
        event_map.insert(
            st_env.get_identifier().unwrap().to_string(),
            from_event_sig(ctx.event_signature_map.borrow().get(&key).unwrap()),
        );
    }

    // Callable functions
    let mut func_map = BTreeMap::new();
    for (key, (solidity_sig, attr)) in ctx.callable_function_map.borrow().iter() {
        let fun = ctx.env.get_function(key.to_qualified_id());
        let abi_sig = from_solidity_sig(&solidity_sig, Some(attr.clone()), "function");
        func_map.insert(fun.get_identifier().to_string(), abi_sig);
    }

    let abi_move = ABIMoveSignature {
        event_map,
        func_map,
    };
    let value_blob = serde_json::to_string_pretty(&abi_move)
        .unwrap()
        .as_bytes()
        .to_vec();
    Metadata {
        key: ABI_MOVE_KEY.as_bytes().to_vec(),
        value: value_blob,
    }
}

/// Parse Metata into ABIMoveSignature
pub(crate) fn parse_metadata_to_move_sig(metadata: &Metadata) -> Option<ABIMoveSignature> {
    let key = &metadata.key;
    let value = &metadata.value;
    let key_str = str::from_utf8(key).unwrap();
    if key_str == ABI_MOVE_KEY {
        return Some(serde_json::from_str(str::from_utf8(value).unwrap()).unwrap());
    }
    None
}
