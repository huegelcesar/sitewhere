/*
 * Copyright (c) SiteWhere, LLC. All rights reserved. http://www.sitewhere.com
 *
 * The software in this package is published under the terms of the CPAL v1.0
 * license, a copy of which has been included with this distribution in the
 * LICENSE.txt file.
 */
package com.sitewhere.hbase.device;

import java.io.IOException;
import java.nio.ByteBuffer;

import org.apache.hadoop.hbase.client.Delete;
import org.apache.hadoop.hbase.client.Get;
import org.apache.hadoop.hbase.client.HTableInterface;
import org.apache.hadoop.hbase.client.Put;
import org.apache.hadoop.hbase.client.Result;
import org.apache.hadoop.hbase.util.Bytes;

import com.sitewhere.core.SiteWherePersistence;
import com.sitewhere.hbase.IHBaseContext;
import com.sitewhere.hbase.ISiteWhereHBase;
import com.sitewhere.hbase.common.HBaseUtils;
import com.sitewhere.hbase.encoder.PayloadMarshalerResolver;
import com.sitewhere.hbase.uid.IdManager;
import com.sitewhere.rest.model.device.Zone;
import com.sitewhere.spi.SiteWhereException;
import com.sitewhere.spi.SiteWhereSystemException;
import com.sitewhere.spi.device.ISite;
import com.sitewhere.spi.device.IZone;
import com.sitewhere.spi.device.request.IZoneCreateRequest;
import com.sitewhere.spi.error.ErrorCode;
import com.sitewhere.spi.error.ErrorLevel;

/**
 * HBase specifics for dealing with SiteWhere zones.
 * 
 * @author Derek
 */
public class HBaseZone {

	/** Length of site identifier (subset of 8 byte long) */
	public static final int ZONE_IDENTIFIER_LENGTH = 4;

	/**
	 * Create a new zone.
	 * 
	 * @param context
	 * @param site
	 * @param request
	 * @return
	 * @throws SiteWhereException
	 */
	public static IZone createZone(IHBaseContext context, ISite site, IZoneCreateRequest request)
			throws SiteWhereException {
		Long siteId = IdManager.getInstance().getSiteKeys().getValue(site.getToken());
		if (siteId == null) {
			throw new SiteWhereSystemException(ErrorCode.InvalidSiteToken, ErrorLevel.ERROR);
		}
		Long zoneId = HBaseSite.allocateNextZoneId(context, siteId);
		byte[] rowkey = getPrimaryRowkey(siteId, zoneId);

		// Associate new UUID with zone row key.
		String uuid = IdManager.getInstance().getZoneKeys().createUniqueId(rowkey);

		// Use common processing logic so all backend implementations work the same.
		Zone zone = SiteWherePersistence.zoneCreateLogic(request, site.getToken(), uuid);

		byte[] payload = context.getPayloadMarshaler().encodeZone(zone);

		HTableInterface sites = null;
		try {
			sites = context.getClient().getTableInterface(ISiteWhereHBase.SITES_TABLE_NAME);
			Put put = new Put(rowkey);
			HBaseUtils.addPayloadFields(context.getPayloadMarshaler().getEncoding(), put, payload);
			sites.put(put);
		} catch (IOException e) {
			throw new SiteWhereException("Unable to create zone.", e);
		} finally {
			HBaseUtils.closeCleanly(sites);
		}

		return zone;
	}

	/**
	 * Update an existing zone.
	 * 
	 * @param context
	 * @param token
	 * @param request
	 * @return
	 * @throws SiteWhereException
	 */
	public static Zone updateZone(IHBaseContext context, String token, IZoneCreateRequest request)
			throws SiteWhereException {
		Zone updated = getZone(context, token);

		// Use common update logic so that backend implemetations act the same way.
		SiteWherePersistence.zoneUpdateLogic(request, updated);

		byte[] zoneId = IdManager.getInstance().getZoneKeys().getValue(token);
		byte[] payload = context.getPayloadMarshaler().encodeZone(updated);

		HTableInterface sites = null;
		try {
			sites = context.getClient().getTableInterface(ISiteWhereHBase.SITES_TABLE_NAME);
			Put put = new Put(zoneId);
			HBaseUtils.addPayloadFields(context.getPayloadMarshaler().getEncoding(), put, payload);
			sites.put(put);
		} catch (IOException e) {
			throw new SiteWhereException("Unable to update zone.", e);
		} finally {
			HBaseUtils.closeCleanly(sites);
		}
		return updated;
	}

	/**
	 * Get a zone by unique token.
	 * 
	 * @param context
	 * @param token
	 * @return
	 * @throws SiteWhereException
	 */
	public static Zone getZone(IHBaseContext context, String token) throws SiteWhereException {
		byte[] rowkey = IdManager.getInstance().getZoneKeys().getValue(token);
		if (rowkey == null) {
			return null;
		}

		HTableInterface sites = null;
		try {
			sites = context.getClient().getTableInterface(ISiteWhereHBase.SITES_TABLE_NAME);
			Get get = new Get(rowkey);
			HBaseUtils.addPayloadFields(get);
			Result result = sites.get(get);

			byte[] type = result.getValue(ISiteWhereHBase.FAMILY_ID, ISiteWhereHBase.PAYLOAD_TYPE);
			byte[] payload = result.getValue(ISiteWhereHBase.FAMILY_ID, ISiteWhereHBase.PAYLOAD);
			if ((type == null) || (payload == null)) {
				return null;
			}

			return PayloadMarshalerResolver.getInstance().getMarshaler(type).decodeZone(payload);
		} catch (IOException e) {
			throw new SiteWhereException("Unable to load zone by token.", e);
		} finally {
			HBaseUtils.closeCleanly(sites);
		}
	}

	/**
	 * Delete an existing zone.
	 * 
	 * @param context
	 * @param token
	 * @param force
	 * @return
	 * @throws SiteWhereException
	 */
	public static Zone deleteZone(IHBaseContext context, String token, boolean force)
			throws SiteWhereException {
		byte[] zoneId = IdManager.getInstance().getZoneKeys().getValue(token);
		if (zoneId == null) {
			throw new SiteWhereSystemException(ErrorCode.InvalidZoneToken, ErrorLevel.ERROR);
		}
		Zone existing = getZone(context, token);
		existing.setDeleted(true);
		if (force) {
			IdManager.getInstance().getZoneKeys().delete(token);
			HTableInterface sites = null;
			try {
				Delete delete = new Delete(zoneId);
				sites = context.getClient().getTableInterface(ISiteWhereHBase.SITES_TABLE_NAME);
				sites.delete(delete);
			} catch (IOException e) {
				throw new SiteWhereException("Unable to delete zone.", e);
			} finally {
				HBaseUtils.closeCleanly(sites);
			}
		} else {
			byte[] marker = { (byte) 0x01 };
			SiteWherePersistence.setUpdatedEntityMetadata(existing);
			byte[] payload = context.getPayloadMarshaler().encodeZone(existing);
			HTableInterface sites = null;
			try {
				sites = context.getClient().getTableInterface(ISiteWhereHBase.SITES_TABLE_NAME);
				Put put = new Put(zoneId);
				HBaseUtils.addPayloadFields(context.getPayloadMarshaler().getEncoding(), put, payload);
				put.add(ISiteWhereHBase.FAMILY_ID, ISiteWhereHBase.DELETED, marker);
				sites.put(put);
			} catch (IOException e) {
				throw new SiteWhereException("Unable to set deleted flag for zone.", e);
			} finally {
				HBaseUtils.closeCleanly(sites);
			}
		}
		return existing;
	}

	/**
	 * Get primary row key for a given zone.
	 * 
	 * @param siteId
	 * @return
	 */
	public static byte[] getPrimaryRowkey(Long siteId, Long zoneId) {
		byte[] baserow = HBaseSite.getZoneRowKey(siteId);
		byte[] zoneIdBytes = getZoneIdentifier(zoneId);
		ByteBuffer buffer = ByteBuffer.allocate(baserow.length + zoneIdBytes.length);
		buffer.put(baserow);
		buffer.put(zoneIdBytes);
		return buffer.array();
	}

	/**
	 * Truncate zone id value to expected length. This will be a subset of the full 8-bit
	 * long value.
	 * 
	 * @param value
	 * @return
	 */
	public static byte[] getZoneIdentifier(Long value) {
		byte[] bytes = Bytes.toBytes(value);
		byte[] result = new byte[ZONE_IDENTIFIER_LENGTH];
		System.arraycopy(bytes, bytes.length - ZONE_IDENTIFIER_LENGTH, result, 0, ZONE_IDENTIFIER_LENGTH);
		return result;
	}
}