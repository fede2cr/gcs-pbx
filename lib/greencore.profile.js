dependencies = {
        layers: [
        {
                name: "gcs-dojo.js",
                dependencies: [
                        "dojo.cookie",
                        "dojo.data.ItemFileReadStore",
                        "dojo.fx",
                        "dojo.parser",
                        "dojox.data.JsonRestStore",
                        "dojox.form.DropDownSelect",
                        "dojox.grid.DataGrid",
                        "dojox.grid.TreeGrid",
                        "dojox.layout.ContentPane",
                        "dojox.widget.Portlet",
                ]
        },
        {
                name: "../dijit/dijit.js",
                dependencies: [
                        "dijit.Dialog",
                        "dijit.dijit",
                        "dijit.form.Button",
                        "dijit.form.CheckBox",
                        "dijit.form.ComboBox",
                        "dijit.form.DateTextBox",
                        "dijit.form.FilteringSelect",
                        "dijit.form.Form",
                        "dijit.form.NumberSpinner",
                        "dijit.form.Slider",
                        "dijit.form.Textarea",
                        "dijit.form.TextBox",
                        "dijit.form.TimeTextBox",
                        "dijit.form.ValidationTextBox",
                        "dijit.InlineEditBox",
                        "dijit.layout.AccordionContainer",
                        "dijit.layout.BorderContainer",
                        "dijit.layout.ContentPane",
                        "dijit.layout.StackContainer",
                        "dijit.layout.TabContainer",
                        "dijit.Menu",
                        "dijit.MenuBar",
                        "dijit.MenuBarItem",
                        "dijit.PopupMenuBarItem",
                        "dijit.Tooltip",
                ]
        },
        ],
        prefixes: [
                 [ "dijit", "../dijit" ],
                [ "dojox", "../dojox" ],
        ]
}
