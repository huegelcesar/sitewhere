/*
 * Copyright (c) SiteWhere, LLC. All rights reserved. http://www.sitewhere.com
 *
 * The software in this package is published under the terms of the CPAL v1.0
 * license, a copy of which has been included with this distribution in the
 * LICENSE.txt file.
 */
package com.sitewhere.instance.spi.microservice;

import com.sitewhere.grpc.client.spi.client.ITenantManagementApiChannel;
import com.sitewhere.grpc.client.spi.client.IUserManagementApiChannel;
import com.sitewhere.instance.spi.templates.IInstanceTemplateManager;
import com.sitewhere.spi.microservice.IFunctionIdentifier;
import com.sitewhere.spi.microservice.IGlobalMicroservice;
import com.sitewhere.spi.microservice.scripting.IScriptSynchronizer;

/**
 * API for instance management microservice.
 * 
 * @author Derek
 */
public interface IInstanceManagementMicroservice<T extends IFunctionIdentifier> extends IGlobalMicroservice<T> {

    /**
     * Get instance template manager instance.
     * 
     * @return
     */
    public IInstanceTemplateManager getInstanceTemplateManager();

    /**
     * Get instance script synchronizer.
     * 
     * @return
     */
    public IScriptSynchronizer getInstanceScriptSynchronizer();

    /**
     * Get channel for interacting with user management via gRPC.
     * 
     * @return
     */
    public IUserManagementApiChannel<?> getUserManagementApiChannel();

    /**
     * Get channel for interacting with tenant management via gRPC.
     * 
     * @return
     */
    public ITenantManagementApiChannel<?> getTenantManagementApiChannel();
}
