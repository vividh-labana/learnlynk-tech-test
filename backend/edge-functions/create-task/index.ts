// LearnLynk Tech Test - Task 3: Edge Function create-task
// Author: Vividh Laban
// Description: POST endpoint to create tasks with validation

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Environment variables
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Initialize Supabase client with service role key (bypasses RLS)
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// Type definitions
type CreateTaskPayload = {
  application_id: string;
  task_type: string;
  due_at: string;
  title?: string;
  tenant_id?: string;
};

type ValidationError = {
  field: string;
  message: string;
};

// Valid task types
const VALID_TASK_TYPES = ["call", "email", "review"] as const;

// CORS headers for browser requests
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

/**
 * Validates if a string is a valid UUID
 */
function isValidUUID(str: string): boolean {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(str);
}

/**
 * Validates the request payload
 * Returns array of validation errors (empty if valid)
 */
function validatePayload(body: Partial<CreateTaskPayload>): ValidationError[] {
  const errors: ValidationError[] = [];

  // Validate application_id
  if (!body.application_id) {
    errors.push({ field: "application_id", message: "application_id is required" });
  } else if (!isValidUUID(body.application_id)) {
    errors.push({ field: "application_id", message: "application_id must be a valid UUID" });
  }

  // Validate task_type
  if (!body.task_type) {
    errors.push({ field: "task_type", message: "task_type is required" });
  } else if (!VALID_TASK_TYPES.includes(body.task_type as typeof VALID_TASK_TYPES[number])) {
    errors.push({
      field: "task_type",
      message: `task_type must be one of: ${VALID_TASK_TYPES.join(", ")}`,
    });
  }

  // Validate due_at
  if (!body.due_at) {
    errors.push({ field: "due_at", message: "due_at is required" });
  } else {
    const dueDate = new Date(body.due_at);
    
    // Check if it's a valid date
    if (isNaN(dueDate.getTime())) {
      errors.push({ field: "due_at", message: "due_at must be a valid ISO 8601 timestamp" });
    } 
    // Check if it's in the future
    else if (dueDate <= new Date()) {
      errors.push({ field: "due_at", message: "due_at must be a future timestamp" });
    }
  }

  return errors;
}

/**
 * Main request handler
 */
serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  // Only allow POST method
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed", allowed: ["POST"] }),
      { status: 405, headers: corsHeaders }
    );
  }

  try {
    // Parse request body
    let body: Partial<CreateTaskPayload>;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid JSON in request body" }),
        { status: 400, headers: corsHeaders }
      );
    }

    // Validate payload
    const validationErrors = validatePayload(body);
    if (validationErrors.length > 0) {
      return new Response(
        JSON.stringify({
          error: "Validation failed",
          details: validationErrors,
        }),
        { status: 400, headers: corsHeaders }
      );
    }

    // Verify that the application exists
    const { data: application, error: appError } = await supabase
      .from("applications")
      .select("id, tenant_id")
      .eq("id", body.application_id)
      .single();

    if (appError || !application) {
      return new Response(
        JSON.stringify({
          error: "Validation failed",
          details: [{ field: "application_id", message: "Application not found" }],
        }),
        { status: 400, headers: corsHeaders }
      );
    }

    // Insert the task
    const { data: task, error: insertError } = await supabase
      .from("tasks")
      .insert({
        application_id: body.application_id,
        tenant_id: application.tenant_id, // Inherit tenant_id from application
        type: body.task_type,
        due_at: body.due_at,
        title: body.title || `${body.task_type} task`, // Default title if not provided
        status: "open",
      })
      .select("id")
      .single();

    if (insertError) {
      console.error("Insert error:", insertError);
      return new Response(
        JSON.stringify({ error: "Failed to create task", details: insertError.message }),
        { status: 500, headers: corsHeaders }
      );
    }

    // Emit Supabase Realtime broadcast event: "task.created"
    const channel = supabase.channel("tasks");
    await channel.send({
      type: "broadcast",
      event: "task.created",
      payload: {
        task_id: task.id,
        application_id: body.application_id,
        task_type: body.task_type,
        due_at: body.due_at,
        tenant_id: application.tenant_id,
        created_at: new Date().toISOString(),
      },
    });

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        task_id: task.id,
      }),
      { status: 200, headers: corsHeaders }
    );

  } catch (err) {
    // Log the error for debugging
    console.error("Unexpected error:", err);
    
    // Return generic 500 error (don't expose internal details)
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: corsHeaders }
    );
  }
});
