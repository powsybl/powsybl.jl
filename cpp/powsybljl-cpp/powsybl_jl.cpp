/**
 * Copyright (c) 2025, RTE (http://www.rte-france.com)
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 * SPDX-License-Identifier: MPL-2.0
 */
#include <string>

#include "jlcxx/jlcxx.hpp"
#include "powsybl-cpp.h"

// Necessary to compile to map struct with no constructor ?
template <> struct jlcxx::IsMirroredType<series> : std::false_type {};
template <> struct jlcxx::IsMirroredType<network_metadata> : std::false_type {};

using StringStringMap = std::map<std::string, std::string>;

void logFromJava(int level, long timestamp, char* loggerName, char* message) {
  //TODO Redirect log properly to julia logger
}

JLCXX_MODULE define_module_powsybl(jlcxx::Module& mod)
{
  mod.add_type<pypowsybl::JavaHandle>("JavaHandle");

  // No automatic mapping of std::map type
  // Only map the basic we use on julia side...
  mod.add_type<StringStringMap>("StringStringMap")
        .method("put_element", [] (StringStringMap& map, const std::string& key, const std::string& value) {
          map[key] = value;
       });

  mod.add_bits<element_type>("ElementType", jlcxx::julia_type("CppEnum"));
  mod.set_const("BUS", element_type::BUS);
  mod.set_const("BUS_FROM_BUS_BREAKER_VIEW", element_type::BUS_FROM_BUS_BREAKER_VIEW);
  mod.set_const("LINE", element_type::LINE);
  mod.set_const("TWO_WINDINGS_TRANSFORMER", element_type::TWO_WINDINGS_TRANSFORMER);
  mod.set_const("THREE_WINDINGS_TRANSFORMER", element_type::THREE_WINDINGS_TRANSFORMER);
  mod.set_const("GENERATOR", element_type::GENERATOR);
  mod.set_const("LOAD", element_type::LOAD);
  mod.set_const("BATTERY", element_type::BATTERY);
  mod.set_const("SHUNT_COMPENSATOR", element_type::SHUNT_COMPENSATOR);
  mod.set_const("NON_LINEAR_SHUNT_COMPENSATOR_SECTION", element_type::NON_LINEAR_SHUNT_COMPENSATOR_SECTION);
  mod.set_const("LINEAR_SHUNT_COMPENSATOR_SECTION", element_type::LINEAR_SHUNT_COMPENSATOR_SECTION);
  mod.set_const("DANGLING_LINE", element_type::DANGLING_LINE);
  mod.set_const("TIE_LINE", element_type::TIE_LINE);
  mod.set_const("LCC_CONVERTER_STATION", element_type::LCC_CONVERTER_STATION);
  mod.set_const("VSC_CONVERTER_STATION", element_type::VSC_CONVERTER_STATION);
  mod.set_const("STATIC_VAR_COMPENSATOR", element_type::STATIC_VAR_COMPENSATOR);
  mod.set_const("SWITCH", element_type::SWITCH);
  mod.set_const("VOLTAGE_LEVEL", element_type::VOLTAGE_LEVEL);
  mod.set_const("SUBSTATION", element_type::SUBSTATION);
  mod.set_const("BUSBAR_SECTION", element_type::BUSBAR_SECTION);
  mod.set_const("HVDC_LINE", element_type::HVDC_LINE);
  mod.set_const("RATIO_TAP_CHANGER_STEP", element_type::RATIO_TAP_CHANGER_STEP);
  mod.set_const("PHASE_TAP_CHANGER_STEP", element_type::PHASE_TAP_CHANGER_STEP);
  mod.set_const("RATIO_TAP_CHANGER", element_type::RATIO_TAP_CHANGER);
  mod.set_const("PHASE_TAP_CHANGER", element_type::PHASE_TAP_CHANGER);
  mod.set_const("REACTIVE_CAPABILITY_CURVE_POINT", element_type::REACTIVE_CAPABILITY_CURVE_POINT);
  mod.set_const("OPERATIONAL_LIMITS", element_type::OPERATIONAL_LIMITS);
  mod.set_const("MINMAX_REACTIVE_LIMITS", element_type::MINMAX_REACTIVE_LIMITS);
  mod.set_const("ALIAS", element_type::ALIAS);
  mod.set_const("IDENTIFIABLE", element_type::IDENTIFIABLE);
  mod.set_const("INJECTION", element_type::INJECTION);
  mod.set_const("BRANCH", element_type::BRANCH);
  mod.set_const("TERMINAL", element_type::TERMINAL);
  mod.set_const("SUB_NETWORK", element_type::SUB_NETWORK);

  mod.add_bits<filter_attributes_type>("FilterAttributes", jlcxx::julia_type("CppEnum"));
  mod.set_const("ALL_ATTRIBUTES", filter_attributes_type::ALL_ATTRIBUTES);
  mod.set_const("DEFAULT_ATTRIBUTES", filter_attributes_type::DEFAULT_ATTRIBUTES);
  mod.set_const("SELECTION_ATTRIBUTES", filter_attributes_type::SELECTION_ATTRIBUTES);

  auto preJavaCall = [](pypowsybl::GraalVmGuard* guard, exception_handler* exc){ };
  auto postJavaCall = [](){ };
  pypowsybl::init(preJavaCall, postJavaCall);
  auto fptr = &::logFromJava;
  pypowsybl::setupLoggerCallback(reinterpret_cast<void *&>(fptr));

  mod.method("get_version_table", &pypowsybl::getVersionTable, "Get an ASCII table with all PowSybBl modules version");
  mod.method("set_java_library_path", [] (std::string const& path) {
        pypowsybl::setJavaLibraryPath(path);
  }, "Set java.library.path JVM property");

  mod.method("close_powsybl", [] () {
          pypowsybl::closePypowsybl();
    }, "Closes powsybl module");

  mod.method("load", [] (std::string const& s, StringStringMap& parameters, std::vector<std::string>& postProcessors) {
    pypowsybl::JavaHandle network = pypowsybl::loadNetwork(s, parameters, postProcessors, nullptr);
    return network;
  }, "Load a network from a file");

  mod.method("create_network", [] (std::string const& name, std::string const& id) {
    return pypowsybl::createNetwork(name, id);
  }, "create an example network");

  mod.method("get_network_available_post_processors", [] () {
      return pypowsybl::getNetworkImportPostProcessors();
    }, "Get available post processors");

  mod.method("get_network_import_formats", [] () {
        return pypowsybl::getNetworkImportFormats();
      }, "Get available import format");

  mod.method("get_network_export_formats", [] () {
          return pypowsybl::getNetworkExportFormats();
        }, "Get available export format");

  mod.method("save_network", [] (pypowsybl::JavaHandle handle, std::string const& file, std::string const& format, StringStringMap const& parameters) {
      pypowsybl::saveNetwork(handle, file, format, parameters, nullptr);
    }, "Save network to a file in a given format");

  mod.add_type<series>("SeriesType")
        .method("name", [](series& s) { return std::string(s.name); })
        .method("index", [](series& s) { return (bool) s.index; })
        .method("type", [](series& s) { return s.type; })
        .method("as_double_array", [](series& s) {
            return jlcxx::ArrayRef<double,1>(static_cast<double*>(s.data.ptr), s.data.length);
         })
        .method("as_int_array", [](series& s) {
                  return jlcxx::ArrayRef<int,1>(static_cast<int*>(s.data.ptr), s.data.length);
        })
        .method("as_string_array", [](series& s) {
                  return pypowsybl::toVector<std::string>((array *) & s.data);
        })
        .method("as_bool_array", [](series& s) {
                  return jlcxx::ArrayRef<bool,1>(static_cast<bool*>(s.data.ptr), s.data.length);
        });

  mod.add_type<network_metadata>("NetworkMetadata")
        .method("id", [](pypowsybl::JavaHandle handle) {
           return std::string(pypowsybl::getNetworkMetadata(handle)->id);
        })
        .method("name", [](pypowsybl::JavaHandle handle) {
           return std::string(pypowsybl::getNetworkMetadata(handle)->name);
        })
        .method("source_format", [](pypowsybl::JavaHandle handle) {
           return std::string(pypowsybl::getNetworkMetadata(handle)->source_format);
        })
        .method("forecast_distance", [](pypowsybl::JavaHandle handle) {
           return pypowsybl::getNetworkMetadata(handle)->forecast_distance;
         })
        .method("case_date", [](pypowsybl::JavaHandle handle) {
           return pypowsybl::getNetworkMetadata(handle)->case_date;
        });

  mod.add_type<pypowsybl::SeriesArray>("SeriesArray")
      .method("as_array", [](pypowsybl::SeriesArray& seriesArray) {
          jlcxx::Array<series> data{ };
          for(int i=0; i < seriesArray.length(); ++i) {
            data.push_back(seriesArray.begin()[i]);
          }
          return data;
      });

  mod.method("create_network_elements_series_array", [] (pypowsybl::JavaHandle handle, element_type type, std::vector<std::string> const& attributes, filter_attributes_type filter_attributes, bool nominal_apparent_power, double per_unit) {
      return pypowsybl::createNetworkElementsSeriesArray(handle, type, filter_attributes, attributes, nullptr, nominal_apparent_power, per_unit);
      }, "Create a network elements series array for a given element type");

  mod.method("create_network_elements_extension_series_array", [] (pypowsybl::JavaHandle handle, std::string const& extension_name, std::string const& table_name) {
        return pypowsybl::createNetworkElementsExtensionSeriesArray(handle, extension_name, table_name);
        }, "Create a network elements extensions series array for a given extension name");

  mod.method("get_extensions_names", [] () {
          return pypowsybl::getExtensionsNames();
          }, "Get all the extensions names available");

}
