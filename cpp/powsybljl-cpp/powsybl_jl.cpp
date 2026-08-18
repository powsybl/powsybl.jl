/**
 * Copyright (c) 2025, RTE (http://www.rte-france.com)
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 * SPDX-License-Identifier: MPL-2.0
 */
#include <string>
#include <functional>
#include <memory>
#include <iostream>
#include <thread>

#include "jlcxx/jlcxx.hpp"
#include "powsybl-cpp.h"

// Necessary to compile to map struct with no constructor ?
template <> struct jlcxx::IsMirroredType<series> : std::false_type {};
template <> struct jlcxx::IsMirroredType<network_metadata> : std::false_type {};
template <> struct jlcxx::IsMirroredType<loadflow_component_result> : std::false_type {};
template <> struct jlcxx::IsMirroredType<slack_bus_result> : std::false_type {};

using StringStringMap = std::map<std::string, std::string>;

void logFromJava(int level, long timestamp, char* loggerName, char* message) {
  //TODO Redirect log properly to julia logger
}

// Template lambda returning an attribute of a class instance
template <typename R, typename P>
std::function<R(P)> attribute_getter(const R P::*pm) {
    return [pm](const P &c) -> const R & { return c.*pm; };
}

// Template lambda setting an attribute of a class instance
template <typename R, typename P>
std::function<void(P&, R)> attribute_setter(R P::*pm) {
    return [pm](P &c, R v) { c.*pm = v; };
}

// Template method generating getter and setter for a given class attribute
template <typename P, typename R>
jlcxx::TypeWrapper<P>& map_attribute_accessor(jlcxx::TypeWrapper<P>& wrapper, std::string const& attribute_name, R P::*pm) {
    wrapper.method(attribute_name, attribute_setter(pm));
    wrapper.method(attribute_name, attribute_getter(pm));
    return wrapper;
}

template <typename T>
jlcxx::Array<T> powsybl_array_to_julia(const pypowsybl::Array<T>* parray) {
  return powsybl_array_to_julia(parray->begin(), parray->length());
}

template <typename T>
jlcxx::Array<T> powsybl_array_to_julia(const array* parray) {
  return powsybl_array_to_julia((T*)parray->ptr, parray->length);
}

template <typename T>
jlcxx::Array<T> powsybl_array_to_julia(const T* ptr, int length) {
  jlcxx::Array<T> jlArray{ };
  for(int i=0; i < length; ++i) {
    jlArray.push_back(ptr[i]);
  }
  return jlArray;
}

// Wrap previous method in a convenient function
// Jlcxx wrapper is accessible when we want to provide custom method / lambda
// Simple attribute can be mapped using map_attribute (inspired by pydbind11)
template <typename T>
class CustomMapper {
public:
    CustomMapper(jlcxx::Module& module, std::string type_name) :
     type_wrapper(module.add_type<T>(type_name)) {}

    jlcxx::TypeWrapper<T> jlcxx_wrapper() {
      return type_wrapper;
    }

    template <typename R>
    CustomMapper<T>& method_readwrite(std::string const& attribute_name, R T::*pm) {
        map_attribute_accessor(type_wrapper, attribute_name, pm);
        return *this;
    }
    jlcxx::TypeWrapper<T> type_wrapper;
};

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
  mod.set_const("BOUNDARY_LINE", element_type::BOUNDARY_LINE);
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
  mod.method("set_java_library_path", &pypowsybl::setJavaLibraryPath, "Set java.library.path JVM property");

  mod.method("close_powsybl", &pypowsybl::closePypowsybl, "Closes powsybl module");

  mod.method("set_config_read_internal", &pypowsybl::setConfigRead, "Set config read mode");

  mod.method("load", [] (std::string const& s, StringStringMap& parameters, std::vector<std::string>& postProcessors) {
    pypowsybl::JavaHandle network = pypowsybl::loadNetwork(s, parameters, postProcessors, nullptr, false);
    return network;
  }, "Load a network from a file");

  mod.method("create_network", [] (std::string const& name, std::string const& id) {
    return pypowsybl::createNetwork(name, id, false);
  }, "create an example network");

  mod.method("get_network_available_post_processors", &pypowsybl::getNetworkImportPostProcessors, "Get available post processors");
  mod.method("get_network_import_formats", &pypowsybl::getNetworkImportFormats, "Get available import format");
  mod.method("get_network_export_formats", &pypowsybl::getNetworkExportFormats, "Get available export format");

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
          return powsybl_array_to_julia(&seriesArray);
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

  // VoltageInitMode
  mod.add_bits<pypowsybl::VoltageInitMode>("VoltageInitMode", jlcxx::julia_type("CppEnum"));
  mod.set_const("UNIFORM_VALUES", pypowsybl::VoltageInitMode::UNIFORM_VALUES);
  mod.set_const("PREVIOUS_VALUES", pypowsybl::VoltageInitMode::PREVIOUS_VALUES);
  mod.set_const("DC_VALUES", pypowsybl::VoltageInitMode::DC_VALUES);

  // ConnectedComponentMode
  mod.add_bits<pypowsybl::ComponentMode>("ComponentMode", jlcxx::julia_type("CppEnum"));
  mod.set_const("MAIN_CONNECTED", pypowsybl::ComponentMode::MAIN_CONNECTED);
  mod.set_const("ALL_CONNECTED", pypowsybl::ComponentMode::ALL_CONNECTED);
  mod.set_const("MAIN_SYNCHRONOUS", pypowsybl::ComponentMode::MAIN_SYNCHRONOUS);

  // BalanceType
  mod.add_bits<pypowsybl::BalanceType>("BalanceType", jlcxx::julia_type("CppEnum"));
  mod.set_const("PROPORTIONAL_TO_GENERATION_P", pypowsybl::BalanceType::PROPORTIONAL_TO_GENERATION_P);
  mod.set_const("PROPORTIONAL_TO_GENERATION_P_MAX", pypowsybl::BalanceType::PROPORTIONAL_TO_GENERATION_P_MAX);
  mod.set_const("PROPORTIONAL_TO_GENERATION_REMAINING_MARGIN", pypowsybl::BalanceType::PROPORTIONAL_TO_GENERATION_REMAINING_MARGIN);
  mod.set_const("PROPORTIONAL_TO_GENERATION_PARTICIPATION_FACTOR", pypowsybl::BalanceType::PROPORTIONAL_TO_GENERATION_PARTICIPATION_FACTOR);
  mod.set_const("PROPORTIONAL_TO_LOAD", pypowsybl::BalanceType::PROPORTIONAL_TO_LOAD);
  mod.set_const("PROPORTIONAL_TO_CONFORM_LOAD", pypowsybl::BalanceType::PROPORTIONAL_TO_CONFORM_LOAD);

  // LoadFlowComponentStatus
  mod.add_bits<pypowsybl::LoadFlowComponentStatus>("LoadFlowComponentStatus", jlcxx::julia_type("CppEnum"));
  mod.set_const("CONVERGED", pypowsybl::LoadFlowComponentStatus::CONVERGED);
  mod.set_const("FAILED", pypowsybl::LoadFlowComponentStatus::FAILED);
  mod.set_const("MAX_ITERATION_REACHED", pypowsybl::LoadFlowComponentStatus::MAX_ITERATION_REACHED);
  mod.set_const("NO_CALCULATION", pypowsybl::LoadFlowComponentStatus::NO_CALCULATION);

  mod.add_type<slack_bus_result>("SlackBusResult")
          .method("id", [](const slack_bus_result& r) {
             return std::string(r.id);
          })
          .method("active_power_mismatch", [](const slack_bus_result& r) {
             return r.active_power_mismatch;
          });

  mod.add_type<loadflow_component_result>("LoadFlowComponentResult")
          .method("connected_component_num", [](const loadflow_component_result& r) {
             return r.connected_component_num;
          })
          .method("synchronous_component_num", [](const loadflow_component_result& r) {
             return r.synchronous_component_num;
          })
          .method("status", [](const loadflow_component_result& r) {
             return static_cast<pypowsybl::LoadFlowComponentStatus>(r.status);
          })
          .method("status_text", [](const loadflow_component_result& r) {
             return std::string(r.status_text);
          })
          .method("iteration_count", [](const loadflow_component_result& r) {
             return r.iteration_count;
          })
          .method("reference_bus_id", [](const loadflow_component_result& r) {
             return std::string(r.reference_bus_id);
          })
          .method("distributed_active_power", [](const loadflow_component_result& r) {
             return r.distributed_active_power;
          })
          .method("slack_bus_results", [](const loadflow_component_result& r) {
             return powsybl_array_to_julia<slack_bus_result>(&(r.slack_bus_results));
          });

  CustomMapper<pypowsybl::LoadFlowParameters> lfParametersMapper(mod, "LoadFlowParameters");
  lfParametersMapper
    .method_readwrite("voltage_init_mode", &pypowsybl::LoadFlowParameters::voltage_init_mode)
    .method_readwrite("transformer_voltage_control_on", &pypowsybl::LoadFlowParameters::transformer_voltage_control_on)
    .method_readwrite("use_reactive_limits", &pypowsybl::LoadFlowParameters::use_reactive_limits)
    .method_readwrite("phase_shifter_regulation_on", &pypowsybl::LoadFlowParameters::phase_shifter_regulation_on)
    .method_readwrite("twt_split_shunt_admittance", &pypowsybl::LoadFlowParameters::twt_split_shunt_admittance)
    .method_readwrite("shunt_compensator_voltage_control_on", &pypowsybl::LoadFlowParameters::shunt_compensator_voltage_control_on)
    .method_readwrite("read_slack_bus", &pypowsybl::LoadFlowParameters::read_slack_bus)
    .method_readwrite("write_slack_bus", &pypowsybl::LoadFlowParameters::write_slack_bus)
    .method_readwrite("distributed_slack", &pypowsybl::LoadFlowParameters::distributed_slack)
    .method_readwrite("balance_type", &pypowsybl::LoadFlowParameters::balance_type)
    .method_readwrite("dc_use_transformer_ratio", &pypowsybl::LoadFlowParameters::dc_use_transformer_ratio)
    .method_readwrite("countries_to_balance", &pypowsybl::LoadFlowParameters::countries_to_balance)
    .method_readwrite("component_mode", &pypowsybl::LoadFlowParameters::component_mode)
    .method_readwrite("hvdc_ac_emulation", &pypowsybl::LoadFlowParameters::hvdc_ac_emulation)
    .method_readwrite("dc_power_factor", &pypowsybl::LoadFlowParameters::dc_power_factor)
    .method_readwrite("dc", &pypowsybl::LoadFlowParameters::dc)
    .method_readwrite("provider_parameters_keys", &pypowsybl::LoadFlowParameters::provider_parameters_keys)
    .method_readwrite("provider_parameters_values", &pypowsybl::LoadFlowParameters::provider_parameters_values);

  mod.method("default_loadflow_parameters", [] () {
                std::shared_ptr<pypowsybl::LoadFlowParameters> parameters(pypowsybl::createLoadFlowParameters());
                return *parameters;
    }, "Get a LoadFlowParameters filled with the provider defaults");

  mod.method("run_load_flow", [] (const pypowsybl::JavaHandle& network, const pypowsybl::LoadFlowParameters& parameters, bool dc, const std::string& provider) {
                pypowsybl::LoadFlowParameters dcParameters = parameters;
                dcParameters.dc = dc;
                pypowsybl::LoadFlowComponentResultArray* results = pypowsybl::runLoadFlow(network, dcParameters, provider, nullptr);
                return powsybl_array_to_julia(results);
      }, "Run and AC load flow");

  mod.method("create_loadflow_provider_parameters_series_array", [] (const std::string& provider) {
            return pypowsybl::createLoadFlowProviderParametersSeriesArray(provider);
    }, "Create a parameters series array for a given loadflow provider");


  // Single line diagram (SLD) and network area diagram (NAD)

  // Default diagram parameters are built inside each wrapper and the optional
  // per-element override dataframes are left null, so no parameter/dataframe type
  // needs to be marshalled from Julia.

  // Diagram parameters. Both native classes are built by their factory, which fills them
  // with the engine's defaults; neither has a default constructor to fall back on.
  mod.add_bits<pypowsybl::NadLayoutType>("NadLayoutType", jlcxx::julia_type("CppEnum"));
  mod.set_const("NAD_LAYOUT_FORCE_LAYOUT", pypowsybl::NadLayoutType::FORCE_LAYOUT);
  mod.set_const("NAD_LAYOUT_GEOGRAPHICAL", pypowsybl::NadLayoutType::GEOGRAPHICAL);

  mod.add_bits<pypowsybl::EdgeInfoType>("EdgeInfoType", jlcxx::julia_type("CppEnum"));
  mod.set_const("EDGE_INFO_ACTIVE_POWER", pypowsybl::EdgeInfoType::ACTIVE_POWER);
  mod.set_const("EDGE_INFO_REACTIVE_POWER", pypowsybl::EdgeInfoType::REACTIVE_POWER);
  mod.set_const("EDGE_INFO_CURRENT", pypowsybl::EdgeInfoType::CURRENT);
  mod.set_const("EDGE_INFO_NAME", pypowsybl::EdgeInfoType::NAME);
  mod.set_const("EDGE_INFO_VALUE_PERMANENT_LIMIT_PERCENTAGE", pypowsybl::EdgeInfoType::VALUE_PERMANENT_LIMIT_PERCENTAGE);
  mod.set_const("EDGE_INFO_EMPTY", pypowsybl::EdgeInfoType::EMPTY);

  CustomMapper<pypowsybl::SldParameters> sldParametersMapper(mod, "SldParameters");
  sldParametersMapper
    .method_readwrite("use_name", &pypowsybl::SldParameters::use_name)
    .method_readwrite("center_name", &pypowsybl::SldParameters::center_name)
    .method_readwrite("diagonal_label", &pypowsybl::SldParameters::diagonal_label)
    .method_readwrite("nodes_infos", &pypowsybl::SldParameters::nodes_infos)
    .method_readwrite("tooltip_enabled", &pypowsybl::SldParameters::tooltip_enabled)
    .method_readwrite("topological_coloring", &pypowsybl::SldParameters::topological_coloring)
    .method_readwrite("component_library", &pypowsybl::SldParameters::component_library)
    .method_readwrite("display_current_feeder_info", &pypowsybl::SldParameters::display_current_feeder_info)
    .method_readwrite("active_power_unit", &pypowsybl::SldParameters::active_power_unit)
    .method_readwrite("reactive_power_unit", &pypowsybl::SldParameters::reactive_power_unit)
    .method_readwrite("current_unit", &pypowsybl::SldParameters::current_unit);

  mod.method("default_sld_parameters", [] () {
            std::shared_ptr<pypowsybl::SldParameters> parameters(pypowsybl::createSldParameters());
            return *parameters;
    }, "Get SldParameters filled with the engine defaults");

  CustomMapper<pypowsybl::NadParameters> nadParametersMapper(mod, "NadParameters");
  nadParametersMapper
    .method_readwrite("edge_info_along_edge", &pypowsybl::NadParameters::edge_info_along_edge)
    .method_readwrite("id_displayed", &pypowsybl::NadParameters::id_displayed)
    .method_readwrite("power_value_precision", &pypowsybl::NadParameters::power_value_precision)
    .method_readwrite("current_value_precision", &pypowsybl::NadParameters::current_value_precision)
    .method_readwrite("angle_value_precision", &pypowsybl::NadParameters::angle_value_precision)
    .method_readwrite("voltage_value_precision", &pypowsybl::NadParameters::voltage_value_precision)
    .method_readwrite("bus_legend", &pypowsybl::NadParameters::bus_legend)
    .method_readwrite("substation_description_displayed", &pypowsybl::NadParameters::substation_description_displayed)
    .method_readwrite("layout_type", &pypowsybl::NadParameters::layout_type)
    .method_readwrite("scaling_factor", &pypowsybl::NadParameters::scaling_factor)
    .method_readwrite("radius_factor", &pypowsybl::NadParameters::radius_factor)
    .method_readwrite("voltage_level_details", &pypowsybl::NadParameters::voltage_level_details)
    .method_readwrite("injections_added", &pypowsybl::NadParameters::injections_added)
    .method_readwrite("info_side_external", &pypowsybl::NadParameters::info_side_external)
    .method_readwrite("info_middle_side1", &pypowsybl::NadParameters::info_middle_side1)
    .method_readwrite("info_middle_side2", &pypowsybl::NadParameters::info_middle_side2)
    .method_readwrite("info_side_internal", &pypowsybl::NadParameters::info_side_internal)
    .method_readwrite("scale_factor", &pypowsybl::NadParameters::scale_factor)
    .method_readwrite("timeout_seconds", &pypowsybl::NadParameters::timeout_seconds)
    .method_readwrite("edge_info_included", &pypowsybl::NadParameters::edge_info_included)
    .method_readwrite("voltage_level_legends_included", &pypowsybl::NadParameters::voltage_level_legends_included);

  mod.method("default_nad_parameters", [] () {
            std::shared_ptr<pypowsybl::NadParameters> parameters(pypowsybl::createNadParameters());
            return *parameters;
    }, "Get NadParameters filled with the engine defaults");

  mod.method("get_single_line_diagram_svg_and_metadata", [] (pypowsybl::JavaHandle network, std::string const& containerId,
                                                             const pypowsybl::SldParameters& parameters) {
            return pypowsybl::getSingleLineDiagramSvgAndMetadata(network, containerId, parameters, nullptr, nullptr, nullptr);
    }, "Get the single line diagram of a voltage level or substation, with its metadata");

  mod.method("write_single_line_diagram_svg", [] (pypowsybl::JavaHandle network, std::string const& containerId,
                                                  std::string const& svgFile, std::string const& metadataFile,
                                                  const pypowsybl::SldParameters& parameters) {
            pypowsybl::writeSingleLineDiagramSvg(network, containerId, svgFile, metadataFile, parameters, nullptr, nullptr, nullptr);
    }, "Write the single line diagram of a voltage level or substation to an SVG file");

  // A matrix of substations is described by its ids and the length of each row, so only
  // basic vectors cross the boundary; the wrapper rebuilds the rows.
  static const auto to_matrix = [] (std::vector<std::string> const& ids, std::vector<int> const& rowLengths) {
      std::vector<std::vector<std::string>> matrix;
      matrix.reserve(rowLengths.size());
      int offset = 0;
      for (int length : rowLengths) {
          matrix.emplace_back(ids.begin() + offset, ids.begin() + offset + length);
          offset += length;
      }
      return matrix;
  };

  mod.method("get_matrix_multi_substation_svg_and_metadata", [] (pypowsybl::JavaHandle network,
                                                                 std::vector<std::string> const& ids,
                                                                 std::vector<int> const& rowLengths,
                                                                 const pypowsybl::SldParameters& parameters) {
            return pypowsybl::getMatrixMultiSubstationSvgAndMetadata(network, to_matrix(ids, rowLengths),
                                                                     parameters, nullptr, nullptr, nullptr);
    }, "Get a multi-substation single line diagram laid out as a matrix, with its metadata");

  mod.method("write_matrix_multi_substation_single_line_diagram_svg", [] (pypowsybl::JavaHandle network,
                                                                          std::vector<std::string> const& ids,
                                                                          std::vector<int> const& rowLengths,
                                                                          std::string const& svgFile,
                                                                          std::string const& metadataFile,
                                                                          const pypowsybl::SldParameters& parameters) {
            pypowsybl::writeMatrixMultiSubstationSingleLineDiagramSvg(network, to_matrix(ids, rowLengths), svgFile,
                                                                      metadataFile, parameters, nullptr, nullptr, nullptr);
    }, "Write a multi-substation single line diagram laid out as a matrix to an SVG file");

  mod.method("get_default_branch_labels_nad", [] (pypowsybl::JavaHandle network) {
            return pypowsybl::getNetworkAreaDiagramDefaultBranchLabels(network);
    }, "Get the default network area diagram branch labels");

  mod.method("get_default_twt_labels_nad", [] (pypowsybl::JavaHandle network) {
            return pypowsybl::getNetworkAreaDiagramDefaultTwtLabels(network);
    }, "Get the default network area diagram three winding transformer labels");

  mod.method("get_default_injections_labels_nad", [] (pypowsybl::JavaHandle network) {
            return pypowsybl::getNetworkAreaDiagramDefaultInjectionsLabels(network);
    }, "Get the default network area diagram injection labels");

  mod.method("get_default_bus_descriptions_nad", [] (pypowsybl::JavaHandle network) {
            return pypowsybl::getNetworkAreaDiagramDefaultBusDescriptions(network);
    }, "Get the default network area diagram bus descriptions");

  mod.method("get_default_voltage_level_descriptions_nad", [] (pypowsybl::JavaHandle network) {
            return pypowsybl::getNetworkAreaDiagramDefaultVoltageLevelDescriptions(network);
    }, "Get the default network area diagram voltage level descriptions");

  mod.method("get_single_line_diagram_component_library_names", [] () {
            return pypowsybl::getSingleLineDiagramComponentLibraryNames();
    }, "Get the names of the available single line diagram component libraries");

  mod.method("get_network_area_diagram_svg_and_metadata", [] (pypowsybl::JavaHandle network, std::vector<std::string> const& voltageLevelIds,
                                                              int depth, double highNominalVoltageBound, double lowNominalVoltageBound,
                                                              const pypowsybl::NadParameters& parameters) {
            return pypowsybl::getNetworkAreaDiagramSvgAndMetadata(network, voltageLevelIds, depth,
                                                                  highNominalVoltageBound, lowNominalVoltageBound, parameters,
                                                                  nullptr, nullptr, nullptr, nullptr, nullptr, nullptr,
                                                                  nullptr, nullptr, nullptr);
    }, "Get the network area diagram, with its metadata");

  mod.method("write_network_area_diagram_svg", [] (pypowsybl::JavaHandle network, std::string const& svgFile, std::string const& metadataFile,
                                                   std::vector<std::string> const& voltageLevelIds, int depth,
                                                   double highNominalVoltageBound, double lowNominalVoltageBound,
                                                   const pypowsybl::NadParameters& parameters) {
            pypowsybl::writeNetworkAreaDiagramSvg(network, svgFile, metadataFile, voltageLevelIds, depth,
                                                  highNominalVoltageBound, lowNominalVoltageBound, parameters,
                                                  nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr);
    }, "Write the network area diagram to an SVG file");

  mod.method("get_network_area_diagram_displayed_voltage_levels", [] (pypowsybl::JavaHandle network,
                                                                      std::vector<std::string> const& voltageLevelIds, int depth) {
            return pypowsybl::getNetworkAreaDiagramDisplayedVoltageLevels(network, voltageLevelIds, depth);
    }, "Get the voltage levels displayed in a network area diagram for the given filter");
}
