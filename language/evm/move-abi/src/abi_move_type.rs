// Copyright (c) The Diem Core Contributors
// Copyright (c) The Move Contributors
// SPDX-License-Identifier: Apache-2.0

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

use crate::abi_signature_type::ABIJsonSignature;

#[derive(Serialize, Deserialize)]
pub struct ABIMoveSignature {
    // Move type -> Ethereum event abi
    pub event_map: BTreeMap<String, ABIJsonSignature>,

    // Move function -> Ethereum pub function abi
    pub func_map: BTreeMap<String, ABIJsonSignature>,
}
