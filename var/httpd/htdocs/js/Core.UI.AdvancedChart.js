// --
// OTOBO is a web-based ticketing system for service organisations.
// --
// Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
// Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/
// --
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.
// --

/*global d3, nv, canvg, StringView */

"use strict";

var Core = Core || {};
Core.UI = Core.UI || {};

/**
 * @namespace Core.UI.AdvancedChart
 * @memberof Core.UI
 * @author
 * @description
 *      Chart drawing.
 */
Core.UI.AdvancedChart = (function (TargetNS) {

    // Default colors for the charts
    var Colors = [ '#C51B3D', '#20AD7D', '#8D23A8', '#0F22EF', '#D79D00', '#AFBC62', '#D82981', '#78A7FC', '#DFC01B', '#43B261', '#53758D', '#C1AE45', '#6CD13D', '#E0CA0E', '#652188', '#3EBB34', '#8F53EA', '#956669', '#34A0FB', '#F50178', '#AB766A', '#BEA029', '#ABE124', '#A68477', '#F7D084', '#93F0A5', '#B54667', '#F12D25', '#1DBA13', '#21AF23', '#3B62C0', '#876CDC', '#3DE6A0', '#CCD77F', '#B91583', '#8CFFFB', '#073641', '#38E1E9', '#1A5F2D', '#ED603F', '#3BB3AA', '#FA2216', '#34E25C', '#B6716A', '#E5845B', '#497FC2', '#ABCCEE', '#222047', '#DFE514', '#FFA84F', '#388B85', '#D21AEF', '#811A26', '#206057', '#557FDB', '#F148CC', '#DAFF4E', '#FCF072', '#792DA8', '#50DC0B', '#8FDC7A', '#954958', '#74575C', '#AC5CAF', '#4FF2BF', '#E4FC17', '#6ADB42', '#4B693B', '#5D7BA1', '#BF1B1C', '#A00AC1', '#13CEE0', '#02C7C0', '#21EAD8', '#C87D39', '#AEAB86', '#DA9998', '#AAB717', '#8496E6', '#FAE782', '#120BD9', '#1A3B4C', '#3F7E68', '#6FCF6B', '#5564DE', '#6E07AD', '#0C847C', '#1BB8A2', '#101DF8', '#85DE9B', '#D0AD74', '#B803D8', '#0E3C7E', '#E8E05E', '#8E36DD', '#2ADC85', '#13E17B', '#A8AE41', '#C3AA40', '#9CFD3C', '#A5782F', '#E33C5B', '#8F33D8', '#59BF4F', '#FECFB0', '#B553D8', '#2CB590', '#01045E', '#CA78AC', '#8AA596', '#54BB79', '#3A5E0E', '#F10F55', '#D205AA', '#234D8D', '#3D2F8A', '#9B4F95', '#E96E9C', '#47E4C9', '#FFC3D4', '#11231A', '#DA529F', '#789D72', '#AB9906', '#205F33', '#444685', '#05067A', '#6E2FC9', '#165AF5', '#026619', '#96EEC6', '#4DB433', '#E9219F', '#AA5F55', '#558BCA', '#56034C', '#A896DD', '#9C7CD0', '#B8B170', '#7D6F92', '#9E8A2D', '#7D6134', '#ED069E', '#74625E', '#3DC9C5', '#C64507', '#274987', '#D74EEE', '#C53379', '#1A6E42', '#308859', '#F70419', '#BE10CF', '#E841CC', '#AD60CB', '#30BB80', '#5886C9' ];

    // add dependencies to chart libs here (e.g. nvd3 etc.)
    if (!Core.Debug.CheckDependency('Core.UI.AdvancedChart', 'nv', 'nvd3')) {
        return false;
    }

    /**
     * @name UpdatePreferences
     * @memberof Core.UI.AdvancedChart
     * @function
     * @param {String} PrefName
     * @param {Array} PrefValue
     * @description
     *      Update chart preferences on server.
     */
    TargetNS.UpdatePreferences = function(PrefName, PrefValue) {
        var URL = Core.Config.Get('CGIHandle'),
            Data = {
                Action: 'AgentPreferences',
                Subaction: 'UpdateAJAX',
                Key: PrefName
            },
            Preferences = Core.Config.Get('Pref-' + PrefName) || {};

        if (!PrefName || !PrefName.length) {
            return;
        }
        Preferences = Core.Config.Get('Pref-' + PrefName) || {};
        // Merge pref settings
        $.each(PrefValue, function(ChartType, Values) {
            $.each(Values, function (Key, Value) {
                if (typeof Preferences[ChartType] === 'undefined') {
                    Preferences[ChartType] = {};
                }
                Preferences[ChartType][Key] = Value;
            });
        });
        Data.Value = Core.JSON.Stringify(Preferences);

        // update pref
        Core.AJAX.FunctionCall(URL, Data, $.noop);
    };

    /**
     * @private
     * @name DrawLineChart
     * @memberof Core.UI.AdvancedChart
     * @function
     * @param {Array} RawData - Raw JSON data.
     * @param {DOMObject} Element - Selector of the (SVG) element to use.
     * @param {Object} Options - Additional options.
     * @param {Boolean} [Options.HideLegend] - Don't display the legend (optional).
     * @param {Boolean} [Options.Duration] - Transition duration in ms, default 0 (no transition).
     * @param {Boolean} [Options.PreferencesKey] - Name of an agent preferences key save
     *      persistent D3 statistic settings to (currently used from the dashboard).
     * @param {Boolean} [Options.PreferencesData] - Current value of the D3 statistic graph settings.
     * @param {Boolean} [Options.NoInitAnimation] - Render chart without animation during initialization (default false). Usefull for PDF generation.
     * @description
     *      Initializes an nvd3 chart with data generated by a frontend module.
     */
    function DrawLineChart(RawData, Element, Options) {
        var Headings,
            ResultData = [],
            ValueFormat = 'd', // y axis format is by default "integer"
            Counter = 0,
            PreferencesKey = Options.PreferencesKey,
            PreferencesData = Options.PreferencesData;

        // First RawData element is not needed
        RawData.shift();
        Headings = RawData.shift();

        if (PreferencesData && typeof PreferencesData.Line !== 'undefined') {
            PreferencesData = PreferencesData.Line;
        }
        else {
            PreferencesData = {};
        }

        $.each(RawData, function(DataIndex, DataElement) {
            var ResultLine;

            // Ignore sum row
            if (DataElement[0] === 'Sum') {
                return;
            }

            ResultLine = {
                key: DataElement[0],
                color: Colors[Counter % Colors.length],
                disabled: (PreferencesData && PreferencesData.Filter && $.inArray(DataElement[0], PreferencesData.Filter) === -1) ? true : false,
                area: true,
                values: []
            };

            $.each(Headings, function(HeadingIndex, HeadingElement){
                var Value;
                // First element is x axis label
                if (HeadingIndex === 0){
                    return;
                }
                // Ignore sum col
                if (typeof HeadingElement === 'undefined' ||  HeadingElement === 'Sum') {
                    return;
                }

                Value = parseFloat(DataElement[HeadingIndex]);

                if (isNaN(Value)) {
                    return;
                }

                // Check if value is a floating point number and not an integer
                if (Value % 1) {
                    ValueFormat = ',1f'; // Set y axis format to float
                }

                // nv d3 does not work correcly with non numeric values
                ResultLine.values.push({
                    x: HeadingIndex,
                    y: Value
                });
            });
            ResultData.push(ResultLine);
            Counter++;
        });

        // production mode
        nv.dev = false;

        nv.addGraph(function() {

            var Chart = nv.models.OTOBOlineChart(),
                ShowLegend = Options.HideLegend ? false : true,
                InitDuration = Options.NoInitAnimation ? 0 : 500;

            // don't let nv/d3 exceptions block the rest of OTOBO JavaScript
            try {

                Chart.staggerLabels(true);

                Chart.margin({
                    top: 20,
                    right: 70,
                    bottom: 50,
                    left: 70
                });

                Chart.useInteractiveGuideline(true)
                    .duration(Options.Duration || 0)
                    .showLegend(ShowLegend)
                    .showYAxis(true)
                    .showXAxis(true);

                Chart.dispatch.on('stateChange', function(state) {

                    function getControlSelection(controlState) {
                        var Control = [];
                        $.each(controlState, function (Key, Value) {
                            if (typeof Value.disabled === 'undefined' || !Value.disabled) {
                                Control.push(Value.key);
                            }
                        });
                        return Control;
                    }

                    if (typeof state.disabled !== 'undefined') {
                        TargetNS.UpdatePreferences(PreferencesKey, {'Line': { 'Filter': getControlSelection(ResultData) }});
                    }

                });

                Chart.xAxis.tickFormat(function(d) {
                    return Headings[d];
                });

                Chart.yAxis
                    .tickFormat(d3.format(ValueFormat));

                d3.select(Element)
                    .datum(ResultData)
                    .transition()
                    .duration(InitDuration)
                    .call(Chart);

                nv.utils.windowResize(Chart.update);
            }
            catch (Error) {
                Core.Debug.Log(Error);
            }

            return Chart;
        });
    }

    /**
     * @private
     * @name DrawSimpleLineChart
     * @memberof Core.UI.AdvancedChart
     * @function
     * @param {Array} RawData - Raw JSON data.
     * @param {DOMObject} Element - Selector of the (SVG) element to use.
     * @param {Object} Options - Additional options.
     * @param {Boolean} [Options.HideLegend] - Don't display the legend (optional).
     * @param {Boolean} [Options.Duration] - Transition duration in ms, default 0 (no transition).
     * @param {Boolean} [Options.NoInitAnimation] - Render chart without animation during initialization (default false). Usefull for PDF generation.
     * @description
     *      Initializes a simple nvd3 chart with data generated by a frontend module.
     */
    function DrawSimpleLineChart(RawData, Element, Options) {
        var Headings,
            ResultData = [],
            ValueFormat = 'd', // y axis format is by default "integer"
            Counter = 0,
            InitDuration = Options.NoInitAnimation ? 0 : 500;

        // First RawData element is not needed
        RawData.shift();
        Headings = RawData.shift();

        $.each(RawData, function(DataIndex, DataElement) {
            var ResultLine;

            // Ignore sum row
            if (DataElement[0] === 'Sum') {
                return;
            }

            ResultLine = {
                key: DataElement[0],
                color: Colors[Counter % Colors.length],
                disabled: false,
                area: true,
                values: []
            };

            $.each(Headings, function(HeadingIndex){
                var Value;
                // First element is x axis label
                if (HeadingIndex === 0){
                    return;
                }

                Value = parseFloat(DataElement[HeadingIndex]);

                if (isNaN(Value)) {
                    return;
                }

                // Check if value is a floating point number and not an integer
                if (Value % 1) {
                    ValueFormat = ',1f'; // Set y axis format to float
                }

                // nv d3 does not work correcly with non numeric values
                ResultLine.values.push({
                    x: HeadingIndex,
                    y: Value
                });
            });
            ResultData.push(ResultLine);
            Counter++;
        });

        // production mode
        nv.dev = false;

        nv.addGraph(function() {

            var Chart = nv.models.OTOBOlineChart(),
                ShowLegend = Options.HideLegend ? false : true;

            // don't let nv/d3 exceptions block the rest of OTOBO JavaScript
            try {

                Chart.margin({
                    top: 20,
                    right: 10,
                    bottom: 30,
                    left: 30
                });

                Chart.useInteractiveGuideline(true)
                    .duration(Options.Duration || 0)
                    .reduceXTicks(Options.ReduceXTicks)
                    .showLegend(ShowLegend)
                    .showYAxis(true)
                    .showXAxis(true);

                Chart.xAxis.tickFormat(function(d) {
                    return Headings[d];
                });

                Chart.xAxis.tickValues([1, 2, 3, 4, 5, 6, 7]);

                Chart.yAxis
                    .tickFormat(d3.format(ValueFormat));

                d3.select(Element)
                    .datum(ResultData)
                    .transition()
                    .duration(InitDuration)
                    .call(Chart);

                nv.utils.windowResize(Chart.update);
            }
            catch (Error) {
                Core.Debug.Log(Error);
            }

            return Chart;
        });
    }

    /**
     * @private
     * @name DrawBarChart
     * @memberof Core.UI.AdvancedChart
     * @function
     * @param {Array} RawData - Raw JSON data.
     * @param {DOMObject} Element - Selector of the (SVG) element to use.
     * @param {Object} Options - Additional options.
     * @param {Boolean} [Options.HideLegend] - Don't display the legend (optional).
     * @param {Boolean} [Options.Duration] - Transition duration in ms, default 0 (no transition).
     * @param {Boolean} [Options.PreferencesKey] - Name of an agent preferences key save
     *      persistent D3 statistic settings to (currently used from the dashboard).
     * @param {Boolean} [Options.PreferencesData] - Current value of the D3 statistic graph settings.
     * @param {Boolean} [Options.NoInitAnimation] - Render chart without animation during initialization (default false). Usefull for PDF generation.
     * @description
     *      Initializes an nvd3 chart with data generated by a frontend module.
     */
    function DrawBarChart(RawData, Element, Options) {

        var Headings,
            ResultData = [],
            ValueFormat = 'd', // y axis format is by default "integer"
            PreferencesKey = Options.PreferencesKey,
            PreferencesData = Options.PreferencesData,
            Counter = 0,
            InitDuration = Options.NoInitAnimation ? 0 : 500;

        if (PreferencesData && typeof PreferencesData.Bar !== 'undefined') {
            PreferencesData = PreferencesData.Bar;
        }
        else {
            PreferencesData = {};
        }

        if (RawData !== null) {
            // First RawData element is not needed
            RawData.shift();
            Headings = RawData.shift();

            $.each(RawData, function(DataIndex, DataElement) {
                var InnerCounter = 0,
                    ResultLine;

                // Ignore sum row
                if (DataElement[0] === 'Sum') {
                    return;
                }

                ResultLine = {
                    key: DataElement[0],
                    color: Colors[Counter % Colors.length],
                    disabled: (PreferencesData && PreferencesData.Filter && $.inArray(DataElement[0], PreferencesData.Filter) === -1) ? true : false,
                    values: []
                };

                $.each(Headings, function(HeadingIndex, HeadingElement){
                    var Value;

                    InnerCounter++;

                    // First element is x axis label
                    if (HeadingIndex === 0){
                        return;
                    }
                    // Ignore sum col
                    if (typeof HeadingElement === 'undefined' ||  HeadingElement === 'Sum') {
                        return;
                    }

                    Value = parseFloat(DataElement[HeadingIndex]);

                    if (isNaN(Value)) {
                        return;
                    }

                    // Check if value is a floating point number and not an integer
                    if (Value % 1) {
                        ValueFormat = ',1f'; // Set y axis format to float
                    }

                    // nv d3 does not work correcly with non numeric values
                    // because it could happen that x axis headings occur multiple
                    // times (such as Thu 18 for two different months), we
                    // add a custom label for uniquity of the headings which is being
                    // removed later (see OTOBOmultiBarChart.js)
                    ResultLine.values.push({
                        x: '__LABEL_START__' + InnerCounter + '__LABEL_END__' + HeadingElement + ' ',
                        y: Value
                    });
                });
                ResultData.push(ResultLine);
                Counter++;
            });
        }

        // production mode
        nv.dev = false;

        nv.addGraph(function() {

            var Chart = nv.models.OTOBOmultiBarChart(),
                ShowLegend = Options.HideLegend ? false : true;

            // don't let nv/d3 exceptions block the rest of OTOBO JavaScript
            try {

                Chart.staggerLabels(true);

                Chart.margin({
                    top: 20,
                    right: 20,
                    bottom: 50,
                    left: 50
                });

                Chart.duration(Options.Duration || 0);
                Chart.showLegend(ShowLegend);

                Chart.tooltips(function(key, x, y) {
                    return '<h3>' + key + '</h3>' + '<p>' + x + ': ' + y + '</p>';
                });

                Chart.dispatch.on('stateChange', function(state) {

                    function getControlSelection(controlState) {
                        var Control = [];
                        $.each(controlState, function (Key, Value) {
                            if (typeof Value.disabled === 'undefined' || !Value.disabled) {
                                Control.push(Value.key);
                            }
                        });
                        return Control;
                    }

                    PreferencesData = {
                        'Bar' : {}
                    };

                    if (typeof state.stacked !== 'undefined') {
                        PreferencesData.Bar.State = {};
                        PreferencesData.Bar.State.Style = (state.stacked) ? 'stacked' : '';
                    }
                    if (typeof state.disabled !== 'undefined') {
                        PreferencesData.Bar.Filter = getControlSelection(ResultData);
                    }

                    TargetNS.UpdatePreferences(PreferencesKey, PreferencesData);
                });

                // set stacked/grouped state
                if (PreferencesData && PreferencesData.State) {
                    Chart.stacked((PreferencesData.State.Style === 'stacked') ? true : false);
                }
                Chart.yAxis.axisLabel("Values").tickFormat(d3.format(ValueFormat));

                d3.select(Element)
                    .datum(ResultData)
                    .transition()
                    .duration(InitDuration)
                    .call(Chart);

                nv.utils.windowResize(Chart.update);
            }
            catch (Error) {
                Core.Debug.Log(Error);
            }

            return Chart;
        });
    }

    /**
     * @private
     * @name DrawStackedAreaChart
     * @memberof Core.UI.AdvancedChart
     * @function
     * @param {Array} RawData - Raw JSON data.
     * @param {DOMObject} Element - Selector of the (SVG) element to use.
     * @param {Object} Options - Additional options.
     * @param {Boolean} [Options.HideLegend] - Don't display the legend (optional).
     * @param {Boolean} [Options.Duration] - Transition duration in ms, default 0 (no transition).
     * @param {Boolean} [Options.PreferencesKey] - Name of an agent preferences key save
     *      persistent D3 statistic settings to (currently used from the dashboard).
     * @param {Boolean} [Options.PreferencesData] - Current value of the D3 statistic graph settings.
     * @description
     *      Initializes an nvd3 chart with data generated by a frontend module.
     */
    function DrawStackedAreaChart(RawData, Element, Options) {

        var Headings,
            ResultData = [],
            Counter = 0,
            PreferencesKey = Options.PreferencesKey,
            PreferencesData = Options.PreferencesData;

        // First RawData element is not needed
        RawData.shift();
        Headings = RawData.shift();

        if (PreferencesData && typeof PreferencesData.StackedArea !== 'undefined') {
            PreferencesData = PreferencesData.StackedArea;
        }
        else {
            PreferencesData = {};
        }

        $.each(RawData, function(DataIndex, DataElement) {

            var ResultLine;

            // Ignore sum row
            if (DataElement[0] === 'Sum') {
                return;
            }

            ResultLine = {
                key: DataElement[0],
                color: Colors[Counter % Colors.length],
                disabled: (PreferencesData && PreferencesData.Filter && $.inArray(DataElement[0], PreferencesData.Filter) === -1) ? true : false,
                values: []
            };

            $.each(Headings, function(HeadingIndex, HeadingElement){
                var Value;
                // First element is x axis label
                if (HeadingIndex === 0){
                    return;
                }
                // Ignore sum col
                if (typeof HeadingElement === 'undefined' ||  HeadingElement === 'Sum') {
                    return;
                }

                Value = parseFloat(DataElement[HeadingIndex]);

                if (isNaN(Value)) {
                    return;
                }

                // nv d3 does not work correcly with non numeric values
                ResultLine.values.push([
                    HeadingIndex,
                    Value
                ]);
            });
            ResultData.push(ResultLine);
            Counter++;
        });

        // production mode
        nv.dev = false;

        nv.addGraph(function() {

            var Chart = nv.models.OTOBOstackedAreaChart(),
                ShowLegend = Options.HideLegend ? false : true;

            // don't let nv/d3 exceptions block the rest of OTOBO JavaScript
            try {

                Chart.staggerLabels(true);

                Chart.margin({
                    top: 20,
                    right: 50,
                    bottom: 50,
                    left: 50
                });

                Chart.duration(Options.Duration || 0);
                Chart.showLegend(ShowLegend);

                Chart.useInteractiveGuideline(true);

                Chart.dispatch.on('stateChange', function(state) {

                    function getControlSelection(controlState) {
                        var Control = [];
                        $.each(controlState, function (Key, Value) {
                            if (typeof Value.disabled === 'undefined' || !Value.disabled) {
                                Control.push(Value.key);
                            }
                        });
                        return Control;
                    }

                    PreferencesData = {
                        'StackedArea' : {}
                    };

                    if (typeof state.style !== 'undefined') {
                        PreferencesData.StackedArea.State = {};
                        PreferencesData.StackedArea.State.Style = state.style;
                    }
                    if (typeof state.disabled !== 'undefined') {
                        PreferencesData.StackedArea.Filter = getControlSelection(ResultData);
                    }

                    TargetNS.UpdatePreferences(PreferencesKey, PreferencesData);
                });

                Chart.x(function(d) { return d[0]; })
                    .y(function(d) { return d[1]; })
                    .showControls(true)
                    .clipEdge(true);

                // remove the sum element
                Headings[Headings.indexOf('Sum')] = undefined;

                // set stacked/grouped state
                if (PreferencesData && PreferencesData.State && PreferencesData.State.Style) {
                    Chart.style(PreferencesData.State.Style);
                }

                // xAxis should have the data from rawdata as labels
                Chart.xAxis
                    .tickFormat(function(d) {
                        return Headings[d];
                    });
                Chart.yAxis
                    .tickFormat(d3.format(',.0f'));

                d3.select(Element)
                    .datum(ResultData)
                    .call(Chart);

                nv.utils.windowResize(Chart.update);
            }
            catch (Error) {
                Core.Debug.Log(Error);
            }

            return Chart;
        });
    }

    /**
     * @name Init
     * @memberof Core.UI.AdvancedChart
     * @function
     * @param {String} Type - Type of the chart, e.g. Bar, Line, StackedArea, etc.
     * @param {Object} RawData - Raw JSON data.
     * @param {DOMObject} Element - Selector of the (SVG) element to use.
     * @param {Object} Options - Additional options.
     * @param {Boolean} [Options.HideLegend] - Don't display the legend (optional).
     * @param {Boolean} [Options.Duration] - Transition duration in ms, default 0 (no transition).
     * @param {Boolean} [Options.PreferencesKey] - Name of an agent preferences key save
     *      persistent D3 statistic settings to (currently used from the dashboard).
     * @param {Boolean} [Options.PreferencesData] - Current value of the D3 statistic graph settings.
     * @description
     *      Initializes a chart.
     */
    TargetNS.Init = function(Type, RawData, Element, Options) {
        Options = Options || {};

        switch (Type) {
            case 'Bar':
            case 'D3::BarChart':
                DrawBarChart(RawData, Element, Options);
                break;
            case 'D3::SimpleLineChart':
                DrawSimpleLineChart(RawData, Element, Options);
                break;
            case 'StackedArea':
            case 'D3::StackedAreaChart':
                DrawStackedAreaChart(RawData, Element, Options);
                break;
            case 'Line':
            case 'D3::LineChart':
            default:
                DrawLineChart(RawData, Element, Options);
                break;
        }

        $('#download-svg').on('click', function() {
            // window.btoa() does not work because it does not support Unicode DOM strings.
            this.href = TargetNS.ConvertSVGtoBase64($('#svg-container'));
        });
        $('#download-png').on('click', function() {
            this.href = TargetNS.ConvertSVGtoPNG($('#svg-container'));
        });
    };

    /**
     * @name GetSVGContent
     * @memberof Core.UI.AdvancedChart
     * @private
     * @function
     * @param {jQueryObject} $SVGContainer - The element containing the SVG element. There should be no other content.
     * @return {String} - The prepared SVG content as a string.
     * @description
     *      This method serializes SVG from the DOM to a string. For this purpose,
     *      some attributes coming from CSS are actually set also in the SVG elements
     *      so that for export / rendering they are present even if the CSS is not there
     *      any more.
     */
    function GetSVGContent($SVGContainer) {
        var $Clone,
            ReplaceMap = {
            'text': ['font-family', 'font-size'],
            'line': ['fill', 'stroke', 'opacity', 'shape-rendering', 'stroke-opacity'],
            'path': ['fill', 'stroke', 'opacity', 'shape-rendering', 'stroke-opacity']
        };

        $.each(ReplaceMap, function(Selector, Attributes){
            $(Selector, $SVGContainer).each(function() {
                var $Element = $(this);
                $.each(Attributes, function(){
                    var CSSAttribute;
                    if ($Element.attr(this)) {
                        return;
                    }
                    CSSAttribute = $Element.css(this);
                    if (!CSSAttribute) {
                        return;
                    }
                    $Element.attr(this, CSSAttribute);
                });
            });
        });

        // Remove controls for export.
        $Clone = $SVGContainer.clone();
        $Clone.find('.nv-controlsWrap').remove();

        return $Clone.html().trim();
    }

    /**
     * @name ConvertSVGtoPNG
     * @memberof Core.UI.AdvancedChart
     * @function
     * @param {jQueryObject} $SVGContainer - The element containing the SVG element. There should be no other content.
     * @return {String} - The base64 data URL containing the PNG data.
     * @description
     *      Convert an SVG element to a PNG data URL.
     */
    TargetNS.ConvertSVGtoPNG = function($SVGContainer) {

        var SVGContent = GetSVGContent($SVGContainer), // Canvg requires trimmed content
            Height = $SVGContainer.css('height'),
            Width = $SVGContainer.css('width'),
            $CanvasContainer,
            $Canvas,
            $Canvas2,
            Canvas2Context;

        $Canvas = $('<canvas></canvas>').attr('height', Height).attr('width', Width);
        $Canvas2 = $('<canvas></canvas>').attr('height', Height).attr('width', Width);

        $CanvasContainer = $('<div style="position: absolute; top: 0; visibility: hidden;"></div>')
            .append($Canvas)
            .append($Canvas2)
            .appendTo('body');

        // First transfer the SVG content to the first canvas. This will be transparent.
        canvg(
            $Canvas.get(0),
            SVGContent,
            { ignoreMouse: true, ignoreAnimations: true }
        );
        $Canvas.get(0).svg.stop();

        // Now transfer content of first canvas to second canvas with white background.
        Canvas2Context = $Canvas2.get(0).getContext('2d');
        Canvas2Context.fillStyle = "white";
        Canvas2Context.fillRect(0, 0, Width.replace('px', ''), Height.replace('px', ''));
        Canvas2Context.drawImage($Canvas.get(0), 0, 0);

        $CanvasContainer.remove();
        return $Canvas2.get(0).toDataURL('image/png');
    };

    /**
     * @name ConvertSVGtoBase64
     * @memberof Core.UI.AdvancedChart
     * @function
     * @param {jQueryObject} $SVGContainer - The element containing the SVG element. There should be no other content.
     * @return {String} - The base64 data URL containing the SVG data with a proper XML header.
     * @description
     *      Convert an SVG element to an SVG data URL.
     */
    TargetNS.ConvertSVGtoBase64 = function($SVGContainer) {
        // window.btoa() does not work because it does not support Unicode DOM strings.
        var SVGPrefix = '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">',
            UnicodeStringView = new StringView(SVGPrefix + GetSVGContent($SVGContainer));
        return 'data:image/svg+xml;base64,' + UnicodeStringView.toBase64();
    };

    return TargetNS;
}(Core.UI.AdvancedChart || {}));
