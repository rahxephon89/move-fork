// Copyright (c) The Diem Core Contributors
// Copyright (c) The Move Contributors
// SPDX-License-Identifier: Apache-2.0

type {:datatype} $1_aggregator_factory_AggregatorFactory;
function {:constructor} $1_aggregator_factory_AggregatorFactory($phantom_table: Table int (int)): $1_aggregator_factory_AggregatorFactory;
function {:inline} $Update'$1_aggregator_factory_AggregatorFactory'_phantom_table(s: $1_aggregator_factory_AggregatorFactory, x: Table int (int)): $1_aggregator_factory_AggregatorFactory {
    $1_aggregator_factory_AggregatorFactory(x)
}
function $IsValid'$1_aggregator_factory_AggregatorFactory'(s: $1_aggregator_factory_AggregatorFactory): bool {
    true
}
function {:inline} $IsEqual'$1_aggregator_factory_AggregatorFactory'(s1: $1_aggregator_factory_AggregatorFactory, s2: $1_aggregator_factory_AggregatorFactory): bool {
    s1 == s2
}
var $1_aggregator_factory_AggregatorFactory_$memory: $Memory $1_aggregator_factory_AggregatorFactory;

function $1_aggregator_factory_spec_new_aggregator(limit: int) : $1_aggregator_Aggregator;

axiom (forall limit: int :: {$1_aggregator_factory_spec_new_aggregator(limit)}
    (var agg := $1_aggregator_factory_spec_new_aggregator(limit);
     $1_aggregator_spec_get_limit(agg) == limit));

axiom (forall limit: int :: {$1_aggregator_factory_spec_new_aggregator(limit)}
     (var agg := $1_aggregator_factory_spec_new_aggregator(limit);
     $1_aggregator_spec_aggregator_get_val(agg) == 0));
