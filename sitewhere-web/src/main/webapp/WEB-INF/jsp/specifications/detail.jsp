<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core"%>
<c:set var="sitewhere_title" value="View Specification" />
<c:set var="sitewhere_section" value="devices" />
<c:set var="use_highlight" value="true" />
<%@ include file="../includes/top.inc"%>

<!-- Title Bar -->
<div class="sw-title-bar content k-header" style="margin-bottom: 15px;">
	<h1 class="ellipsis" data-i18n="specifications.detail.title"></h1>
	<div class="sw-title-bar-right">
		<a id="btn-edit-specification" class="btn" href="javascript:void(0)"> <i
			class="fa fa-pencil sw-button-icon"></i> <span data-i18n="public.EditSpecification">Edit
				Specification</span></a>
	</div>
</div>

<!-- Detail panel for selected specification -->
<div id="specification-details" style="line-height: normal;"></div>

<!-- Tab panel -->
<div id="tabs">
	<ul>
		<li class="k-state-active">&nbsp;<font data-i18n="specifications.detail.Commands"></font></li>
		<li>&nbsp;<font data-i18n="specifications.detail.CodeGeneration"></font></li>
		<c:choose>
			<c:when test="${specification.containerPolicy == 'Composite'}">
				<li data-i18n="public.Composition"></li>
			</c:when>
		</c:choose>
	</ul>
	<div>
		<div class="k-header sw-button-bar">
			<div class="sw-button-bar-title" data-i18n="specifications.detail.DeviceCommands"></div>
			<div>
				<a id="btn-refresh-commands" class="btn" href="javascript:void(0)"> <i
					class="fa fa-refresh sw-button-icon"></i> <span data-i18n="public.Refresh">Refresh</span>
				</a> <a id="btn-add-command" class="btn" href="javascript:void(0)"> <i
					class="fa fa-plus sw-button-icon"></i> <span data-i18n="specifications.detail.AddNewCommand">Add
						New Command</span></a>
			</div>
		</div>
		<div id="commands" class="sw-assignment-list"></div>
	</div>
	<div>
		<div class="k-header sw-button-bar">
			<div class="sw-button-bar-title" data-i18n="specifications.detail.GPBD"></div>
			<div>
				<a id="btn-refresh-protobuf" class="btn" href="javascript:void(0)"> <i
					class="fa fa-refresh sw-button-icon"></i> <span data-i18n="public.Refresh">Refresh</span>
				</a> <a id="btn-download-protobuf" class="btn" href="javascript:void(0)"> <i
					class="fa fa-download sw-button-icon"></i> <span data-i18n="specifications.detail.Download">Download</span></a>
			</div>
		</div>
		<div style="max-height: 500px; overflow-y: scroll;">
			<pre class="language-javascript">
				<code id="sw-proto-section"></code>
			</pre>
		</div>
	</div>
	<c:choose>
		<c:when test="${specification.containerPolicy == 'Composite'}">
			<div>
				<div class="k-header sw-button-bar">
					<div class="sw-button-bar-title" data-i18n="specifications.detail.DeviceElementSchema"></div>
					<div>
						<a id="btn-add-unit" class="btn" href="javascript:void(0)"> <i
							class="fa fa-folder-close sw-button-icon"></i> <span
							data-i18n="specifications.detail.AddDeviceUnit">Add Device Unit</span></a> <a id="btn-add-slot"
							class="btn" href="javascript:void(0)"> <i class="fa fa-link sw-button-icon"></i> <span
							data-i18n="specifications.detail.AddDeviceSlot">Add Device Slot</span></a>
					</div>
				</div>
				<div id="sw-composition-section"></div>
			</div>
		</c:when>
	</c:choose>
</div>

<%@ include file="../includes/commandCreateDialog.inc"%>
<%@ include file="../includes/deviceSlotCreateDialog.inc"%>
<%@ include file="../includes/deviceUnitCreateDialog.inc"%>
<%@ include file="../includes/specificationCreateDialog.inc"%>
<%@ include file="../includes/templateSpecificationEntry.inc"%>
<%@ include file="../includes/templateCommandEntry.inc"%>
<%@ include file="../includes/templateCommandParamEntry.inc"%>
<%@ include file="../includes/assetTemplates.inc"%>
<%@ include file="../includes/commonFunctions.inc"%>

<script>
	/** Set sitewhere_title */
	sitewhere_i18next.sitewhere_title = "specifications.detail.title";

	// Token for specification being viewed.
	var specToken = '<c:out value="${specification.token}"/>';

	// Context used for creating new elements.
	var elementContext;

	$(document).ready(
		function() {

			/** Create the tab strip */
			tabs = $("#tabs").kendoTabStrip({
				animation : false
			}).data("kendoTabStrip");

			$("#btn-add-command").click(function() {
				ccOpen(specToken, onCommandCreateSuccess);
			});

			$("#btn-edit-specification").click(function() {
				onSpecificationEditClicked();
			});

			$("#btn-refresh-protobuf").click(function() {
				loadProtobuf();
			});

			$("#btn-download-protobuf").click(
				function(e) {
					e.preventDefault();
					window.location.href =
							"${pageContext.request.contextPath}/api/specifications/" + specToken
									+ "/spec.proto?tenantAuthToken=${tenant.authenticationToken}";
				});

			$("#btn-add-unit").click(function() {
				addTopLevelUnit();
			});

			$("#btn-add-slot").click(function() {
				addTopLevelSlot();
			});

			loadSpecification();
			loadCommands();
		});

	/** Called when edit button on the list entry is pressed */
	function onSpecificationEditClicked() {
		spuOpen(specToken, onSpecificationEditComplete);
	}

	/** Called after successful specification update */
	function onSpecificationEditComplete() {
		loadSpecification();
	}

	/** Called when 'edit command' is clicked */
	function onEditCommand(e, token) {
		var event = e || window.event;
		event.stopPropagation();
		cuOpen(token, onEditCommandComplete);
	}

	/** Called after command has been edited */
	function onEditCommandComplete() {
		loadCommands();
	}

	/** Called after command has been created */
	function onCommandCreateSuccess() {
		loadCommands();
	}

	/** Loads information for the selected specification */
	function loadSpecification() {
		$.getJSON("${pageContext.request.contextPath}/api/specifications/" + specToken
				+ "?tenantAuthToken=${tenant.authenticationToken}", loadGetSuccess, loadGetFailed);
	}

	/** Called on successful specification load request */
	function loadGetSuccess(data, status, jqXHR) {
		var template = kendo.template($("#tpl-specification-entry").html());
		parseSpecificationData(data);
		data.inDetailView = true;
		$('#specification-details').html(template(data));
		loadProtobuf();
		refreshDeviceElementSchema(data, status, jqXHR);
	}

	/** Handle error on getting specification data */
	function loadGetFailed(jqXHR, textStatus, errorThrown) {
		handleError(jqXHR, "Unable to load specification data.");
	}

	/** Called when 'delete command' is clicked */
	function onDeleteCommand(e, token) {
		var event = e || window.event;
		event.stopPropagation();
		swConfirm(i18next("includes.DeleteCommand"), i18next("specifications.detail.AYSTYWTDDCW")
				+ " token '" + token + "'?", function(result) {
			if (result) {
				$.deleteJSON("${pageContext.request.contextPath}/api/commands/" + token
						+ "?tenantAuthToken=${tenant.authenticationToken}", commandDeleteSuccess,
					commandDeleteFailed);
			}
		});
	}

	/** Called on successful command delete request */
	function commandDeleteSuccess(data, status, jqXHR) {
		loadCommands();
	}

	/** Handle error on deleting command */
	function commandDeleteFailed(jqXHR, textStatus, errorThrown) {
		handleError(jqXHR, "Unable to delete command.");
	}

	/** Loads commands for the selected specification */
	function loadCommands() {
		$.getJSON("${pageContext.request.contextPath}/api/specifications/" + specToken
				+ "/namespaces?tenantAuthToken=${tenant.authenticationToken}", loadCommandsSuccess,
			loadCommandsFailed);
	}

	/** Called on successful specification commands load request */
	function loadCommandsSuccess(data, status, jqXHR) {
		var template = kendo.template($("#tpl-command-entry").html());
		var commandData;

		var index;
		var nsHtml, allHtml = "";
		for (var i = 0, ns; ns = data.results[i]; i++) {
			nsHtml =
					"<div class='sw-spec-namespace'><div class='sw-spec-ns-header'><strong>Namespace:</strong> "
			nsHtml +=
					"<span class='sw-spec-namespace-name'>" + ((ns.value) ? ns.value : "(Default)")
							+ "</span>";
			nsHtml += "</div>";
			for (var j = 0, command; command = ns.commands[j]; j++) {
				commandData = {
					"commandHtml" : swHtmlifyCommand(command),
					"command" : command
				};
				nsHtml += template(commandData);
			}
			nsHtml += "</div>";
			allHtml += nsHtml;
		}
		$('#commands').html(allHtml);
	}

	/** Handle error on getting specification command data */
	function loadCommandsFailed(jqXHR, textStatus, errorThrown) {
		handleError(jqXHR, "Unable to load specification command data.");
	}

	/** Load google protocol buffer definition */
	function loadProtobuf() {
		$.get("${pageContext.request.contextPath}/api/specifications/" + specToken
				+ "/proto?tenantAuthToken=${tenant.authenticationToken}", function(data) {
			$("#sw-proto-section").text('\n' + data);
			Prism.highlightElement(document.getElementById('sw-proto-section'));
		});
	}

	/** Add a top-level device unit */
	function addTopLevelSlot() {
		createSlot("/");
	}

	/** Add a top-level device unit */
	function addTopLevelUnit() {
		createUnit("/");
	}

	/** Open the 'create device slot' dialog */
	function createSlot(context) {
		elementContext = context;
		loadSchemaForUpdate(showCreateSlotDialog);
	}

	/** Open the 'create device unit' dialog */
	function createUnit(context) {
		elementContext = context;
		loadSchemaForUpdate(showCreateUnitDialog);
	}

	/** Delete the given slot */
	function deleteSlot(context) {
		elementContext = context;
		loadSchemaForUpdate(handleDeleteSlot);
	}

	/** Delete the given unit */
	function deleteUnit(context) {
		elementContext = context;
		loadSchemaForUpdate(handleDeleteUnit);
	}

	/** Reloads specification and routes to a callback that will execute updates. */
	function loadSchemaForUpdate(callback) {
		$.getJSON("${pageContext.request.contextPath}/api/specifications/" + specToken
				+ "?tenantAuthToken=${tenant.authenticationToken}", callback, loadGetFailed);
	}

	/** Called on successful specification load request */
	function showCreateSlotDialog(data, status, jqXHR) {
		var schema = data.deviceElementSchema;
		if (!schema) {
			return;
		}
		dscOpen(specToken, elementContext, schema, onDeviceSlotCreated);
	}

	/** Called on successful specification load request */
	function showCreateUnitDialog(data, status, jqXHR) {
		var schema = data.deviceElementSchema;
		if (!schema) {
			return;
		}
		ducOpen(specToken, elementContext, schema, onDeviceUnitCreated);
	}

	/** Delete the given unit */
	function handleDeleteSlot(data, status, jqXHR) {
		var schema = data.deviceElementSchema;
		if (!schema) {
			return;
		}
		swConfirm("Delete Device Slot", "Are you sure that you want to delete the selected device slot?",
			function(result) {
				if (result) {
					var updated = swRemoveDeviceSlotForContext(elementContext, schema);
					if (updated) {
						var specData = {
							"deviceElementSchema" : updated,
						}
						$.putJSON("${pageContext.request.contextPath}/api/specifications/" + specToken
								+ "?tenantAuthToken=${tenant.authenticationToken}", specData,
							refreshDeviceElementSchema, onDeleteSlotFail);
					}
				}
			});
	}

	/** Delete the given unit */
	function handleDeleteUnit(data, status, jqXHR) {
		var schema = data.deviceElementSchema;
		if (!schema) {
			return;
		}
		swConfirm("Delete Device Unit", "Are you sure that you want to delete the selected device unit?",
			function(result) {
				if (result) {
					var updated = swRemoveDeviceUnitForContext(elementContext, schema);
					if (updated) {
						var specData = {
							"deviceElementSchema" : updated,
						}
						$.putJSON("${pageContext.request.contextPath}/api/specifications/" + specToken
								+ "?tenantAuthToken=${tenant.authenticationToken}", specData,
							refreshDeviceElementSchema, onDeleteUnitFail);
					}
				}
			});
	}

	/** Handle failed call to delete device slot */
	function onDeleteSlotFail(jqXHR, textStatus, errorThrown) {
		handleError(jqXHR, "Unable to delete device slot.");
	}

	/** Handle failed call to delete device unit */
	function onDeleteUnitFail(jqXHR, textStatus, errorThrown) {
		handleError(jqXHR, "Unable to delete device unit.");
	}

	/** Called after a device slot is successfully created */
	function onDeviceSlotCreated() {
		loadSchemaForUpdate(refreshDeviceElementSchema);
	}

	/** Called after a device unit is successfully created */
	function onDeviceUnitCreated() {
		loadSchemaForUpdate(refreshDeviceElementSchema);
	}

	/** Load HTML for device element schema */
	function refreshDeviceElementSchema(data, status, jqXHR) {
		var schema = data.deviceElementSchema;
		if (!schema) {
			return;
		}
		var shtml = getUnitHtml(schema, "");
		$('#sw-composition-section').html(shtml);
	}

	/** Create HTML for a device unit */
	function getUnitHtml(unit, context) {
		var uhtml = "";
		var slength = unit.deviceSlots.length;
		uhtml += "<div class='sw-device-slot-container'>";
		uhtml +=
				"<div class='sw-device-slot-header'><i class='f fa-link sw-button-icon'></i> Device Slots</div>";
		if (slength == 0) {
			uhtml +=
					"<div class='sw-nodata-container'<span class='sw-nodata-message'>No Slots Currently Configured</span></div>";
		} else {
			for (var i = 0; i < slength; i++) {
				uhtml += getSlotHtml(unit.deviceSlots[i], context);
			}
		}
		uhtml += "</div>";
		var ulength = unit.deviceUnits.length;
		for (var i = 0; i < ulength; i++) {
			var relContext = context + "/" + unit.deviceUnits[i].path;
			uhtml += "<div class='sw-device-unit-container sw-list-entry'>";
			uhtml += getUnitHeaderHtml(unit.deviceUnits[i], relContext);
			uhtml += getUnitHtml(unit.deviceUnits[i], relContext);
			uhtml += "</div>";
		}
		return uhtml;
	}

	/** Create HTML for device unit header bar */
	function getUnitHeaderHtml(unit, relContext) {
		var uhtml =
				"<div class='sw-device-unit-header'><i class='fa fa-folder-close sw-button-icon'></i>"
						+ unit.name + " (<span class='sw-device-unit-path'>" + relContext + "</span>)";
		uhtml +=
				"<div class='sw-device-unit-buttons'>"
						+ "<i class='fa fa-folder-close sw-button-icon sw-action-glyph sw-normal-glyph' "
						+ "style='padding-right: 5px;' title='Add Nested Device Unit' onclick=\"createUnit('"
						+ relContext + "');\"></i>"
						+ "<i class='fa fa-link sw-button-icon sw-action-glyph sw-normal-glyph' "
						+ "onclick=\"createSlot('" + relContext + "');\" title='Add Device Slot'></i>"
						+ "<i class='fa fa-remove sw-button-icon sw-action-glyph sw-delete-glyph' "
						+ "onclick=\"deleteUnit('" + relContext + "');\" title='Delete Device Unit'></i>"
						+ "</div></div>";
		return uhtml;
	}

	/** Create HTML for a device slot */
	function getSlotHtml(slot, context) {
		var relContext = context + "/" + slot.path;
		var shtml =
				"<div class='sw-device-slot'><i class='fa fa-link sw-button-icon' style='padding-right: 5px'></i>"
						+ slot.name + " (<span class='sw-device-slot-path'>" + relContext + "</span>)";
		shtml +=
				"<div class='sw-device-slot-buttons'>"
						+ "<i class='fa fa-remove sw-button-icon sw-action-glyph sw-delete-glyph' "
						+ "onclick=\"deleteSlot('" + relContext
						+ "');\" title='Delete Device Slot'></i></div></div>";
		return shtml;
	}
</script>

<%@ include file="../includes/bottom.inc"%>