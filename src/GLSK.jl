# Copyright (c) 2025, RTE (http://www.rte-france.com)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
# SPDX-License-Identifier: MPL-2.0

module GLSK
  using ..LibPowsybl
  using ..Network
  using CxxWrap
  using Dates

  """
  A parsed GLSK (Generation and Load Shift Keys) document, loaded with [`load`](@ref).
  It maps each zone and time interval to the injections that absorb a change in the zone's
  net position, together with their participation factors (shift keys).
  """
  mutable struct GLSKDocument
    handle::LibPowsybl.JavaHandle
  end

  """
      load(filename) -> GLSKDocument

  Load a GLSK document from a file (e.g. a CIM/UCTE GSK XML file).
  """
  load(filename::AbstractString) = GLSKDocument(LibPowsybl.create_glsk_document(String(filename)))

  _instant(t::DateTime) = round(Int, datetime2unix(t))
  _instant(t::Integer) = Int(t)

  """
      get_countries(doc::GLSKDocument) -> Vector{String}

  Return the ids of the zones (countries) defined in the document.
  """
  get_countries(doc::GLSKDocument) = String[String(c) for c in LibPowsybl.get_glsk_countries(doc.handle)]

  """
      get_gsk_time_interval_start(doc::GLSKDocument) -> DateTime

  Return the start (UTC) of the document's validity interval.
  """
  get_gsk_time_interval_start(doc::GLSKDocument) = unix2datetime(LibPowsybl.get_glsk_factors_start_timestamp(doc.handle))

  """
      get_gsk_time_interval_end(doc::GLSKDocument) -> DateTime

  Return the end (UTC) of the document's validity interval.
  """
  get_gsk_time_interval_end(doc::GLSKDocument) = unix2datetime(LibPowsybl.get_glsk_factors_end_timestamp(doc.handle))

  """
      get_points_for_country(doc, network, country, instant) -> Vector{String}

  Return the injection ids participating for `country` at `instant`, resolved against
  `network`. `instant` may be a `DateTime` (interpreted as UTC) or epoch seconds.
  """
  get_points_for_country(doc::GLSKDocument, network::Network.NetworkHandle, country::AbstractString,
                         instant::Union{DateTime, Integer}) =
    String[String(k) for k in LibPowsybl.get_glsk_injection_keys(network.handle, doc.handle, String(country), _instant(instant))]

  """
      get_glsk_factors(doc, network, country, instant) -> Vector{Float64}

  Return the shift-key factors of the injections participating for `country` at `instant`
  (same order as [`get_points_for_country`](@ref)). `instant` may be a `DateTime`
  (interpreted as UTC) or epoch seconds.
  """
  get_glsk_factors(doc::GLSKDocument, network::Network.NetworkHandle, country::AbstractString,
                   instant::Union{DateTime, Integer}) =
    Float64[Float64(f) for f in LibPowsybl.get_glsk_factors(network.handle, doc.handle, String(country), _instant(instant))]
end
