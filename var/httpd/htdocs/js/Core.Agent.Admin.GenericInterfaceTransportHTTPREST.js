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

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};
Core.Agent.Admin = Core.Agent.Admin || {};

/**
 * @namespace Core.Agent.Admin.GenericInterfaceTransportHTTPREST
 * @memberof Core.Agent.Admin
 * @author
 * @description
 *      This namespace contains the special module functions for the GenericInterface Mapping XSLT module.
 */
Core.Agent.Admin.GenericInterfaceTransportHTTPREST = (function (TargetNS) {

    /**
     * @name RemoveValue
     * @memberof Core.Agent.Admin.GenericInterfaceTransportHTTPREST
     * @function
     * @returns {Boolean} Returns false.
     * @param {String} IDSelector - ID of the pressed remove value button.
     * @description
     *      This function removes a value from possible values list and creates a stub input so
     *      the server can identify if a value is empty or deleted (useful for server validation)
     *      It also deletes the Value from the DefaultValues list
     */
    TargetNS.RemoveValue = function (IDSelector){

        // copy HTML code for an input replacement for the deleted value
        var $Clone = $('.DeletedValue').clone(),

        // get the index of the value to delete (its always the second element (1) in this RegEx
        $ObjectIndex = IDSelector.match(/.+_(\d+)/)[1],

        // get the key name to remove it from the defaults select
        $Key = $('#Key_' + $ObjectIndex).val();

        // set the input replacement attributes to match the deleted original value
        // new value and other controls are not needed anymore
        $Clone.attr('id', 'Key' + '_' + $ObjectIndex);
        $Clone.attr('name', 'Key' + '_' + $ObjectIndex);
        $Clone.removeClass('DeletedValue');

        // add the input replacement to the mapping type so it can be parsed and distinguish from
        // empty values by the server
        $('#' + IDSelector).closest('fieldset').append($Clone);

        // remove the value from default list
        if ($Key !== ''){
            $('#DefaultValue').find("option[value='" + $Key + "']").remove();
            $('#DefaultValue').trigger('redraw.InputField');
        }

        // remove possible value
        $('#' + IDSelector).parent().remove();

        return false;
    };

    /**
     * @name AddValue
     * @memberof Core.Agent.Admin.GenericInterfaceTransportHTTPREST
     * @function
     * @returns {Boolean} Returns false
     * @param {Object} ValueInsert - HTML container of the value mapping row.
     * @description
     *      This function adds a new value to the possible values list
     */
    TargetNS.AddValue = function (ValueInsert) {

        // clone key dialog
        var $Clone = $('.ValueTemplate').clone(),
            ValueCounter = $('#ValueCounter').val();

        // increment key counter
        ValueCounter++;

        // remove unnecessary classes
        $Clone.removeClass('Hidden ValueTemplate');

        // add needed class
        $Clone.addClass('ValueRow');

        // copy values and change ids and names
        $Clone.find(':input, a.RemoveButton').each(function(){
            var ID = $(this).attr('id');
            $(this).attr('id', ID + '_' + ValueCounter);
            $(this).attr('name', ID + '_' + ValueCounter);

            $(this).addClass('Validate_Required');

            // set error controls
            $(this).parent().find('#' + ID + 'Error').attr('id', ID + '_' + ValueCounter + 'Error');
            $(this).parent().find('#' + ID + 'Error').attr('name', ID + '_' + ValueCounter + 'Error');

            $(this).parent().find('#' + ID + 'ServerError').attr('id', ID + '_' + ValueCounter + 'ServerError');
            $(this).parent().find('#' + ID + 'ServerError').attr('name', ID + '_' + ValueCounter + 'ServerError');

            // add event handler to remove button
            if($(this).hasClass('RemoveButton')) {
                // bind click function to remove button
                $(this).on('click', function () {
                    TargetNS.RemoveValue($(this).attr('id'));
                    return false;
                });
            }
        });

        $Clone.find('label').each(function(){
            var FOR = $(this).attr('for');
            $(this).attr('for', FOR + '_' + ValueCounter);
        });

        // prepend to container
        ValueInsert.prepend($Clone);

        // set new value for KeyName
        $('#ValueCounter').val(ValueCounter);

        return false;
    };

    /**
     * @name Init
     * @memberof Core.Agent.Admin.GenericInterfaceTransportHTTPREST
     * @function
     * @description
     *      This function binds events to certain actions
     */
    TargetNS.Init = function () {

        // bind change function to Authentication field
        $('#AuthType').on('change', function(){
            if ($(this).val() === 'BasicAuth') {
                $('.BasicAuthField').removeClass('Hidden');
                $('.BasicAuthField').find('#BasicAuthUser').each(function(){
                    $(this).addClass('Validate_Required');
                });
            }
            else {
                $('.BasicAuthField').addClass('Hidden');
                $('.BasicAuthField').find('#BasicAuthUser').each(function(){
                    $(this).removeClass('Validate_Required');
                });
            }
        });

        // bind change function to Use Proxy field
        $('#UseProxy').on('change', function(){
            if ($(this).val() === 'Yes') {
                $('.ProxyField').removeClass('Hidden');
                $('#ProxyExclude').addClass('Validate_Required');
                Core.UI.InputFields.Activate($('.ProxyField'));
            }
            else {
                $('.ProxyField').addClass('Hidden');
            }
        });

        // bind change function to Use SSL field
        $('#UseSSL').on('change', function(){
            if ($(this).val() === 'Yes') {
                $('.SSLField').removeClass('Hidden');
            }

            else {
                $('.SSLField').addClass('Hidden');
            }
        });

        // special handling for value counter
        $('.ValueRow :input[name^="Key"]').each(function(i){

            // set value counter
            $('#ValueCounter').val(i + 1);
        })

        //bind click function to add button
        $('#AddValue').on('click', function () {
            TargetNS.AddValue(
                $(this).closest('fieldset').find('.ValueInsert')
            );
            return false;
        });

        //bind click function to remove button
        $('.ValueRemove').on('click', function () {
            TargetNS.RemoveValue($(this).attr('id'));
            return false;
        });
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.Admin.GenericInterfaceTransportHTTPREST || {}));
