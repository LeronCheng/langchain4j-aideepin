-- 安装pgvector扩展（https://github.com/pgvector/pgvector）
-- 安装Apache AGE扩展（https://github.com/apache/age）
-- CREATE EXTENSION IF NOT EXISTS vector;
-- CREATE EXTENSION IF NOT EXISTS age;

SET client_encoding = 'UTF8';
CREATE SCHEMA public;

-- update_time trigger
CREATE OR REPLACE FUNCTION update_modified_column()
    RETURNS TRIGGER AS
$$
BEGIN
    NEW.update_time = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TABLE public.adi_ai_image
(
    id                 bigserial primary key,
    user_id            bigint                  default 0                     not null,
    uuid               character varying(32)   default ''::character varying not null,
    ai_model_name      character varying(45)   default ''::character varying not null,
    prompt             character varying(1024) default ''::character varying not null,
    generate_size      character varying(20)   default ''::character varying not null,
    generate_quality   character varying(20)   default ''::character varying not null,
    generate_number    integer                 default 1                     not null,
    original_image     character varying(1000) default ''::character varying not null,
    mask_image         character varying(1000) default ''::character varying not null,
    resp_images_path   character varying(2048) default ''::character varying not null,
    generated_images   character varying(2048) default ''::character varying not null,
    interacting_method smallint                default '1'::smallint         not null,
    process_status     smallint                default '1'::smallint         not null,
    create_time        timestamp               default CURRENT_TIMESTAMP     not null,
    update_time        timestamp               default CURRENT_TIMESTAMP     not null,
    is_deleted         boolean                 default false                 not null,
    CONSTRAINT adi_ai_image_generate_number_check CHECK (((generate_number >= 1) AND (generate_number <= 10))),
    CONSTRAINT adi_ai_image_interacting_method_check CHECK ((interacting_method = ANY (ARRAY [1, 2, 3]))),
    CONSTRAINT adi_ai_image_process_status_check CHECK ((process_status = ANY (ARRAY [1, 2, 3]))),
    CONSTRAINT adi_ai_image_user_id_check CHECK ((user_id >= 0))
);
ALTER TABLE ONLY public.adi_ai_image
    ADD CONSTRAINT udx_uuid UNIQUE (uuid);
COMMENT ON TABLE public.adi_ai_image IS '作图任务 | Images generated by ai';
COMMENT ON COLUMN public.adi_ai_image.user_id IS 'The user who generated the image';
COMMENT ON COLUMN public.adi_ai_image.uuid IS 'The uuid of the request of generated images';
COMMENT ON COLUMN public.adi_ai_image.ai_model_name IS 'Image model name';
COMMENT ON COLUMN public.adi_ai_image.prompt IS 'The prompt for generating images';
COMMENT ON COLUMN public.adi_ai_image.generate_size IS 'DALL·E 2:256x256, 512x512 or 1024x1024;DALL·E 3:1024x1024, 1024x1792 or 1792x1024';
COMMENT ON COLUMN public.adi_ai_image.generate_quality IS 'Only DALL·E 3:hd,standard';
COMMENT ON COLUMN public.adi_ai_image.generate_number IS 'The number of images to generate. Must be between 1 and 10. defaults to 1.';
COMMENT ON COLUMN public.adi_ai_image.original_image IS 'The path of the original image (local path or http path), interacting_method must be 2/3';
COMMENT ON COLUMN public.adi_ai_image.mask_image IS 'The path of the mask image (local path or http path), interacting_method must be 2';
COMMENT ON COLUMN public.adi_ai_image.resp_images_path IS 'The url of the generated images which from openai response, separated by commas';
COMMENT ON COLUMN public.adi_ai_image.generated_images IS '生成的多张图片文件uuid,逗号隔开 | The uuid of the generated images, separated by commas';
COMMENT ON COLUMN public.adi_ai_image.interacting_method IS '1: Creating images from scratch based on a text prompt; 2: Creating edits of an existing image based on a new text prompt; 3: Creating variations of an existing image';
COMMENT ON COLUMN public.adi_ai_image.process_status IS 'Generate image status, 1: doing, 2: fail, 3: success';
COMMENT ON COLUMN public.adi_ai_image.create_time IS 'Timestamp of record creation';
COMMENT ON COLUMN public.adi_ai_image.update_time IS 'Timestamp of record last update, automatically updated on each update';
COMMENT ON COLUMN public.adi_ai_image.is_deleted IS 'Flag indicating whether the record is deleted (0: not deleted, 1: deleted)';


CREATE TABLE public.adi_ai_model
(
    id                bigserial primary key,
    name              varchar(45)   default ''                not null,
    type              varchar(45)   default 'text'            not null,
    setting           varchar(500)  default ''                not null,
    remark            varchar(1000) default '',
    platform          varchar(45)   default ''                not null,
    context_window    int           default 0                 not null,
    max_input_tokens  int           default 0                 not null,
    max_output_tokens int           default 0                 not null,
    is_enable         boolean       default false             not null,
    create_time       timestamp     default CURRENT_TIMESTAMP not null,
    update_time       timestamp     default CURRENT_TIMESTAMP not null,
    is_deleted        boolean       default false             not null
);

COMMENT ON TABLE public.adi_ai_model IS 'ai模型';
COMMENT ON COLUMN public.adi_ai_model.type IS '模型类型(以输出类型或使用目的做判断，如dalle2可文本和图像输入，但使用方关注的是输出的图片，所以属于image类型),eg: text,image,embedding,rerank';
COMMENT ON COLUMN public.adi_ai_model.name IS 'The name of the AI model';
COMMENT ON COLUMN public.adi_ai_model.remark IS 'Additional remarks about the AI model';
COMMENT ON COLUMN public.adi_ai_model.platform IS 'eg: openai,dashscope,qianfan,ollama';
COMMENT ON COLUMN public.adi_ai_model.context_window IS 'LLM context window';
COMMENT ON COLUMN public.adi_ai_model.is_enable IS '1: Normal usage, 0: Not available';
COMMENT ON COLUMN public.adi_ai_model.create_time IS 'Timestamp of record creation';
COMMENT ON COLUMN public.adi_ai_model.update_time IS 'Timestamp of record last update, automatically updated on each update';

-- 示例数据
-- https://platform.openai.com/docs/models/gpt-3-5-turbo
INSERT INTO adi_ai_model (name, type, platform, context_window, max_input_tokens, max_output_tokens, is_enable)
VALUES ('gpt-3.5-turbo', 'text', 'openai', 16385, 12385, 4096, false);
INSERT INTO adi_ai_model (name, type, platform, is_enable)
VALUES ('dall-e-2', 'image', 'openai', false);
INSERT INTO adi_ai_model (name, type, platform, is_enable)
VALUES ('dall-e-3', 'image', 'openai', false);
-- https://help.aliyun.com/zh/dashscope/developer-reference/model-introduction?spm=a2c4g.11186623.0.i39
INSERT INTO adi_ai_model (name, type, platform, context_window, max_input_tokens, max_output_tokens, is_enable)
VALUES ('qwen-turbo', 'text', 'dashscope', 8192, 6144, 1536, false);
-- https://console.bce.baidu.com/qianfan/modelcenter/model/buildIn/detail/am-bg7n2rn2gsbb
INSERT INTO adi_ai_model (name, type, platform, context_window, max_input_tokens, max_output_tokens, is_enable, setting)
VALUES ('ERNIE-Speed-8K', 'text', 'qianfan', 131072, 126976, 4096, false, '{"endpoint":"ernie-speed-128k"}');
INSERT INTO adi_ai_model (name, type, platform, is_enable)
VALUES ('tinydolphin', 'text', 'ollama', false);

CREATE TABLE public.adi_conversation_preset
(
    id                bigserial primary key,
    uuid              varchar(32)   default ''                not null,
    title             varchar(45)   default ''                not null,
    remark            varchar(1000) default ''                not null,
    ai_system_message varchar(1000) default ''                not null,
    create_time       timestamp     default CURRENT_TIMESTAMP not null,
    update_time       timestamp     default CURRENT_TIMESTAMP not null,
    is_deleted        boolean       default false             not null
);
COMMENT ON TABLE public.adi_conversation_preset IS '预设会话(角色)表';

COMMENT ON COLUMN public.adi_conversation_preset.title IS '标题';

COMMENT ON COLUMN public.adi_conversation_preset.remark IS '描述';

COMMENT ON COLUMN public.adi_conversation_preset.ai_system_message IS '提供给LLM的系统信息';

create trigger trigger_conversation_preset
    before update
    on adi_conversation_preset
    for each row
execute procedure update_modified_column();

-- 示例数据
INSERT INTO adi_conversation_preset (uuid, title, remark, ai_system_message)
VALUES ('26a8f54c560948d6b2d4969f08f3f2fb', '开发工程师', '技术好', '你是一个经验丰富的开发工程师,开发技能极其熟练');
INSERT INTO adi_conversation_preset (uuid, title, remark, ai_system_message)
VALUES ('16a8f54c560949d6b2d4969f08f3f2fc', '财务专家', '算数很厉害,相关法律知识也很了解',
        '你是一个经验丰富的财务专家,精通财务分析、预算编制、财务报告、税务法规等领域知识');

CREATE TABLE public.adi_conversation
(
    id                        bigserial primary key,
    user_id                   bigint                  default 0                     not null,
    uuid                      character varying(32)   default ''::character varying not null,
    title                     character varying(45)   default ''::character varying not null,
    tokens                    integer                 default 0                     not null,
    ai_system_message         character varying(1000) default ''::character varying not null,
    understand_context_enable boolean                 default false                 not null,
    llm_temperature           numeric(2, 1)           default 0.7                   not null,
    create_time               timestamp               default CURRENT_TIMESTAMP     not null,
    update_time               timestamp               default CURRENT_TIMESTAMP     not null,
    is_deleted                boolean                 default false                 not null
);

COMMENT ON TABLE public.adi_conversation IS '用户会话(角色)表';

COMMENT ON COLUMN public.adi_conversation.user_id IS '用户id';

COMMENT ON COLUMN public.adi_conversation.ai_model IS '模型名称';

COMMENT ON COLUMN public.adi_conversation.title IS '标题';

COMMENT ON COLUMN public.adi_conversation.llm_temperature is '指定LLM响应时的创造性/随机性';


CREATE TABLE public.adi_conversation_preset_rel
(
    id             bigserial primary key,
    uuid           varchar(32) default ''                not null,
    user_id        bigint      default 0                 not null,
    preset_conv_id bigint      default 0                 not null,
    user_conv_id   bigint      default 0                 not null,
    create_time    timestamp   default CURRENT_TIMESTAMP not null,
    update_time    timestamp   default CURRENT_TIMESTAMP not null,
    is_deleted     boolean     default false             not null
);

COMMENT ON TABLE public.adi_conversation_preset_rel IS '预设会话与用户会话关系表';
COMMENT ON COLUMN public.adi_conversation_preset_rel.user_id IS '用户id';
COMMENT ON COLUMN public.adi_conversation_preset_rel.preset_conv_id IS '预设会话id';
COMMENT ON COLUMN public.adi_conversation_preset_rel.user_conv_id IS '用户会话id';

create trigger trigger_conversation_preset_rel
    before update
    on adi_conversation_preset_rel
    for each row
execute procedure update_modified_column();

CREATE TABLE public.adi_conversation_message
(
    id                              bigserial primary key,
    parent_message_id               bigint                default 0                     not null,
    conversation_id                 bigint                default 0                     not null,
    conversation_uuid               character varying(32) default ''::character varying not null,
    remark                          text                                                not null,
    uuid                            character varying(32) default ''::character varying not null,
    message_role                    integer               default 1                     not null,
    tokens                          integer               default 0                     not null,
    user_id                         bigint                default 0                     not null,
    ai_model_id                     bigint                default 0                     not null,
    understand_context_msg_pair_num integer               default 0                     not null,
    create_time                     timestamp             default CURRENT_TIMESTAMP     not null,
    update_time                     timestamp             default CURRENT_TIMESTAMP     not null,
    is_deleted                      boolean               default false                 not null
);
COMMENT ON TABLE public.adi_conversation_message IS '对话消息表';

COMMENT ON COLUMN public.adi_conversation_message.parent_message_id IS '父级消息id';

COMMENT ON COLUMN public.adi_conversation_message.conversation_id IS '对话id';

COMMENT ON COLUMN public.adi_conversation_message.conversation_uuid IS 'conversation''s uuid';

COMMENT ON COLUMN public.adi_conversation_message.remark IS 'ai回复的消息';

COMMENT ON COLUMN public.adi_conversation_message.uuid IS '唯一标识消息的UUID';

COMMENT ON COLUMN public.adi_conversation_message.message_role IS '产生该消息的角色：1: 用户, 2: 系统, 3: 助手';

COMMENT ON COLUMN public.adi_conversation_message.tokens IS '消耗的token数量';

COMMENT ON COLUMN public.adi_conversation_message.user_id IS '用户ID';

COMMENT ON COLUMN public.adi_conversation_message.ai_model_id IS 'adi_ai_model id';

COMMENT ON COLUMN public.adi_conversation_message.understand_context_msg_pair_num IS '上下文消息对数量';

CREATE TABLE public.adi_file
(
    id          bigserial primary key,
    name        character varying(36)  default ''::character varying not null,
    uuid        character varying(32)  default ''::character varying not null,
    ext         character varying(36)  default ''::character varying not null,
    user_id     bigint                 default 0                     not null,
    path        character varying(250) default ''::character varying not null,
    ref_count   integer                default 0                     not null,
    create_time timestamp              default CURRENT_TIMESTAMP     not null,
    update_time timestamp              default CURRENT_TIMESTAMP     not null,
    is_deleted  boolean                default false                 not null,
    md5         character varying(128) default ''::character varying not null
);

COMMENT ON TABLE public.adi_file IS '文件';

COMMENT ON COLUMN public.adi_file.name IS 'File name';

COMMENT ON COLUMN public.adi_file.uuid IS 'UUID of the file';

COMMENT ON COLUMN public.adi_file.ext IS 'File extension';

COMMENT ON COLUMN public.adi_file.user_id IS '0: System; Other: User';

COMMENT ON COLUMN public.adi_file.path IS 'File path';

COMMENT ON COLUMN public.adi_file.ref_count IS 'The number of references to this file';

COMMENT ON COLUMN public.adi_file.create_time IS 'Timestamp of record creation';

COMMENT ON COLUMN public.adi_file.update_time IS 'Timestamp of record last update, automatically updated on each update';

COMMENT ON COLUMN public.adi_file.is_deleted IS '0: Normal; 1: Deleted';

COMMENT ON COLUMN public.adi_file.md5 IS 'MD5 hash of the file';

CREATE TABLE public.adi_prompt
(
    id          bigserial primary key,
    user_id     bigint                 default 0                     not null,
    act         character varying(120) default ''::character varying not null,
    prompt      text                                                 not null,
    create_time timestamp              default CURRENT_TIMESTAMP     not null,
    update_time timestamp              default CURRENT_TIMESTAMP     not null,
    is_deleted  boolean                default false                 not null
);

COMMENT ON TABLE public.adi_prompt IS '提示词';

COMMENT ON COLUMN public.adi_prompt.user_id IS '所属用户(0: system)';

COMMENT ON COLUMN public.adi_prompt.act IS '提示词标题';

COMMENT ON COLUMN public.adi_prompt.prompt IS '提示词内容';

COMMENT ON COLUMN public.adi_prompt.create_time IS 'Timestamp of record creation';

COMMENT ON COLUMN public.adi_prompt.update_time IS 'Timestamp of record last update, automatically updated on each update';

COMMENT ON COLUMN public.adi_prompt.is_deleted IS '0:未删除；1：已删除';

CREATE TABLE public.adi_sys_config
(
    id          bigserial primary key,
    name        character varying(100)  default ''::character varying not null,
    value       character varying(1000) default ''::character varying not null,
    create_time timestamp               default localtimestamp        not null,
    update_time timestamp               default localtimestamp        not null,
    is_deleted  boolean                 default false                 not null
);

COMMENT ON TABLE public.adi_sys_config IS '系统配置表';

COMMENT ON COLUMN public.adi_sys_config.name IS '配置项名称';

COMMENT ON COLUMN public.adi_sys_config.value IS '配置项值';

COMMENT ON COLUMN public.adi_sys_config.create_time IS 'Timestamp of record creation';

COMMENT ON COLUMN public.adi_sys_config.update_time IS 'Timestamp of record last update, automatically updated on each update';

COMMENT ON COLUMN public.adi_sys_config.is_deleted IS '0：未删除；1：已删除';

CREATE TABLE public.adi_user
(
    id                              bigserial primary key,
    name                            character varying(45)  default ''::character varying not null,
    password                        character varying(120) default ''::character varying not null,
    uuid                            character varying(32)  default ''::character varying not null,
    email                           character varying(120) default ''::character varying not null,
    active_time                     timestamp,
    user_status                     smallint               default '1'::smallint         not null,
    is_admin                        boolean                default false                 not null,
    quota_by_token_daily            integer                default 0                     not null,
    quota_by_token_monthly          integer                default 0                     not null,
    quota_by_request_daily          integer                default 0                     not null,
    quota_by_request_monthly        integer                default 0                     not null,
    understand_context_enable       smallint               default '0'::smallint         not null,
    understand_context_msg_pair_num integer                default 3                     not null,
    quota_by_image_daily            integer                default 0                     not null,
    quota_by_image_monthly          integer                default 0                     not null,
    create_time                     timestamp              default CURRENT_TIMESTAMP     not null,
    update_time                     timestamp              default CURRENT_TIMESTAMP     not null,
    is_deleted                      boolean                default false                 not null
);

COMMENT ON TABLE public.adi_user IS '用户表';

COMMENT ON COLUMN public.adi_user.name IS '用户名';

COMMENT ON COLUMN public.adi_user.password IS '密码';

COMMENT ON COLUMN public.adi_user.uuid IS 'UUID of the user';

COMMENT ON COLUMN public.adi_user.email IS '用户邮箱';

COMMENT ON COLUMN public.adi_user.active_time IS '激活时间';

COMMENT ON COLUMN public.adi_user.create_time IS 'Timestamp of record creation';

COMMENT ON COLUMN public.adi_user.update_time IS 'Timestamp of record last update, automatically updated on each update';

COMMENT ON COLUMN public.adi_user.user_status IS '用户状态，1：待验证；2：正常；3：冻结';

COMMENT ON COLUMN public.adi_user.is_admin IS '是否管理员，0：否；1：是';

COMMENT ON COLUMN public.adi_user.is_deleted IS '0：未删除；1：已删除';

COMMENT ON COLUMN public.adi_user.quota_by_token_daily IS '每日token配额';

COMMENT ON COLUMN public.adi_user.quota_by_token_monthly IS '每月token配额';

COMMENT ON COLUMN public.adi_user.quota_by_request_daily IS '每日请求配额';

COMMENT ON COLUMN public.adi_user.quota_by_request_monthly IS '每月请求配额';

COMMENT ON COLUMN public.adi_user.understand_context_enable IS '上下文理解开关';

COMMENT ON COLUMN public.adi_user.understand_context_msg_pair_num IS '上下文消息对数量';

COMMENT ON COLUMN public.adi_user.quota_by_image_daily IS '每日图片配额';

COMMENT ON COLUMN public.adi_user.quota_by_image_monthly IS '每月图片配额';

-- 管理员账号：catkeeper@aideepin.com  密码：123456
INSERT INTO adi_user (name, password, uuid, email, user_status, is_admin)
VALUES ('catkeeper', '$2a$10$z44gncmQk6xCBCeDx55gMe1Zc8uYtOKcoT4/HE2F92VcF7wP2iquG',
        replace(gen_random_uuid()::text, '-', ''), 'catkeeper@aideepin.com', 2, true);

CREATE TABLE public.adi_user_day_cost
(
    id            bigserial primary key,
    user_id       bigint    default 0                 not null,
    day           integer   default 0                 not null,
    requests      integer   default 0                 not null,
    tokens        integer   default 0                 not null,
    create_time   timestamp default CURRENT_TIMESTAMP not null,
    update_time   timestamp default CURRENT_TIMESTAMP not null,
    images_number integer   default 0                 not null,
    is_deleted    boolean   default false             not null
);

COMMENT ON TABLE public.adi_user_day_cost IS '用户每天消耗总量表';

COMMENT ON COLUMN public.adi_user_day_cost.user_id IS '用户ID';

COMMENT ON COLUMN public.adi_user_day_cost.day IS '日期，用7位整数表示，如20230901';

COMMENT ON COLUMN public.adi_user_day_cost.requests IS '请求数量';

COMMENT ON COLUMN public.adi_user_day_cost.tokens IS '消耗的token数量';

COMMENT ON COLUMN public.adi_user_day_cost.create_time IS 'Timestamp of record creation';

COMMENT ON COLUMN public.adi_user_day_cost.update_time IS 'Timestamp of record last update, automatically updated on each update';

COMMENT ON COLUMN public.adi_user_day_cost.images_number IS '图片数量';


CREATE TRIGGER trigger_ai_image_update_time
    BEFORE UPDATE
    ON adi_ai_image
    FOR EACH ROW
EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER trigger_ai_model_update_time
    BEFORE UPDATE
    ON adi_ai_model
    FOR EACH ROW
EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER trigger_conv_update_time
    BEFORE UPDATE
    ON adi_conversation
    FOR EACH ROW
EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER trigger_conv_message_update_time
    BEFORE UPDATE
    ON adi_conversation_message
    FOR EACH ROW
EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER trigger_file_update_time
    BEFORE UPDATE
    ON adi_file
    FOR EACH ROW
EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER trigger_prompt_update_time
    BEFORE UPDATE
    ON adi_prompt
    FOR EACH ROW
EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER trigger_sys_config_update_time
    BEFORE UPDATE
    ON adi_sys_config
    FOR EACH ROW
EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER trigger_user_update_time
    BEFORE UPDATE
    ON adi_user
    FOR EACH ROW
EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER trigger_user_day_cost_update_time
    BEFORE UPDATE
    ON adi_user_day_cost
    FOR EACH ROW
EXECUTE PROCEDURE update_modified_column();

create trigger trigger_ai_model
    before update
    on adi_ai_model
    for each row
execute procedure update_modified_column();


INSERT INTO adi_sys_config (name, value)
VALUES ('openai_setting', '{"secret_key":""}');
INSERT INTO adi_sys_config (name, value)
VALUES ('dashscope_setting', '{"api_key":""}');
INSERT INTO adi_sys_config (name, value)
VALUES ('qianfan_setting', '{"api_key":"","secret_key":""}');
INSERT INTO adi_sys_config (name, value)
VALUES ('ollama_setting', '{"base_url":""}');
INSERT INTO adi_sys_config (name, value)
VALUES ('google_setting',
        '{"url":"https://www.googleapis.com/customsearch/v1","key":"","cx":""}');
INSERT INTO adi_sys_config (name, value)
VALUES ('request_text_rate_limit', '{"times":24,"minutes":3}');
INSERT INTO adi_sys_config (name, value)
VALUES ('request_image_rate_limit', '{"times":6,"minutes":3}');
INSERT INTO adi_sys_config (name, value)
VALUES ('conversation_max_num', '50');
INSERT INTO adi_sys_config (name, value)
VALUES ('quota_by_token_daily', '10000');
INSERT INTO adi_sys_config (name, value)
VALUES ('quota_by_token_monthly', '200000');
INSERT INTO adi_sys_config (name, value)
VALUES ('quota_by_request_daily', '150');
INSERT INTO adi_sys_config (name, value)
VALUES ('quota_by_request_monthly', '3000');
INSERT INTO adi_sys_config (name, value)
VALUES ('quota_by_image_daily', '30');
INSERT INTO adi_sys_config (name, value)
VALUES ('quota_by_image_monthly', '300');
INSERT INTO adi_sys_config (name, value)
VALUES ('quota_by_qa_ask_daily', '50');
INSERT INTO adi_sys_config (name, value)
VALUES ('quota_by_qa_item_monthly', '100');

create table adi_knowledge_base
(
    id                    bigserial primary key,
    uuid                  varchar(32)   default ''::character varying not null,
    title                 varchar(250)  default ''::character varying not null,
    remark                text          default ''::character varying not null,
    is_public             boolean       default false                 not null,
    is_strict             boolean       default true                  not null,
    ingest_max_overlap    int           default 0                     not null,
    ingest_model_name     varchar(45)   default ''::character varying not null,
    ingest_model_id       bigint        default 0                     not null,
    retrieve_max_results  int           default 3                     not null,
    retrieve_min_score    numeric(2, 1) default 0.6                   not null,
    query_llm_temperature numeric(2, 1) default 0.7                   not null,
    owner_id              bigint        default 0                     not null,
    owner_uuid            varchar(32)   default ''::character varying not null,
    owner_name            varchar(45)   default ''::character varying not null,
    star_count            int           default 0                     not null,
    item_count            int           default 0                     not null,
    embedding_count       int           default 0                     not null,
    create_time           timestamp     default CURRENT_TIMESTAMP     not null,
    update_time           timestamp     default CURRENT_TIMESTAMP     not null,
    is_deleted            boolean       default false                 not null
);

comment on table adi_knowledge_base is '知识库';

comment on column adi_knowledge_base.title is '知识库名称';

comment on column adi_knowledge_base.remark is '知识库描述';

comment on column adi_knowledge_base.is_public is '是否公开';

comment on column adi_knowledge_base.is_strict is '是否严格模式,严格模式：严格匹配知识库，知识库中如无搜索结果，直接返回无答案;非严格模式：非严格匹配知识库，知识库中如无搜索结果，将用户提问传给LLM继续请求答案';

comment on column adi_knowledge_base.ingest_max_overlap is '设置文档切块时重叠的最大数量（按token来计），对完整句子切割时才考虑重叠';

comment on column adi_knowledge_base.ingest_model_name is '索引(图谱化)文档时使用的LLM,不指定时使用第1个可用的LLM';

comment on column adi_knowledge_base.ingest_model_id is '索引(图谱化)文档时使用的LLM,不指定时使用第1个可用的LLM';

comment on column adi_knowledge_base.retrieve_max_results is '设置召回向量最大数量,默认为0,表示由系统根据模型的contentWindow自动调整';

comment on column adi_knowledge_base.retrieve_min_score is '设置向量搜索时命中所需的最低分数,为0表示使用默认';

comment on column adi_knowledge_base.query_llm_temperature is '用户查询时指定LLM响应时的创造性/随机性';

comment on column adi_knowledge_base.star_count is '点赞数';

comment on column adi_knowledge_base.item_count is '知识点数量';

comment on column adi_knowledge_base.embedding_count is '向量数';

comment on column adi_knowledge_base.owner_id is '所属人id';

comment on column adi_knowledge_base.owner_uuid is '所属人uuid';

comment on column adi_knowledge_base.owner_name is '所属人名称';

comment on column adi_knowledge_base.create_time is '创建时间';

comment on column adi_knowledge_base.update_time is '更新时间';

comment on column adi_knowledge_base.is_deleted is '0：未删除；1：已删除';

create trigger trigger_kb_update_time
    before update
    on adi_knowledge_base
    for each row
execute procedure update_modified_column();

create table adi_knowledge_base_item
(
    id                           bigserial primary key,
    uuid                         varchar(32)  default ''::character varying not null,
    kb_id                        bigint       default 0                     not null,
    kb_uuid                      varchar(32)  default ''::character varying not null,
    source_file_id               bigint       default 0                     not null,
    title                        varchar(250) default ''::character varying not null,
    brief                        varchar(250) default ''::character varying not null,
    remark                       text         default ''::character varying not null,
    is_embedded                  boolean      default false                 not null,
    embedding_status             int          default 1                     not null,
    embedding_status_change_time timestamp    default CURRENT_TIMESTAMP     not null,
    graphical_status             int          default 1                     not null,
    graphical_status_change_time timestamp    default CURRENT_TIMESTAMP     not null,
    create_time                  timestamp    default CURRENT_TIMESTAMP     not null,
    update_time                  timestamp    default CURRENT_TIMESTAMP     not null,
    is_deleted                   boolean      default false                 not null
);

comment on table adi_knowledge_base_item is '知识库-条目';

comment on column adi_knowledge_base_item.kb_id is '所属知识库id';

comment on column adi_knowledge_base_item.source_file_id is '来源文件id';

comment on column adi_knowledge_base_item.title is '条目标题';

comment on column adi_knowledge_base_item.brief is '条目内容摘要';

comment on column adi_knowledge_base_item.remark is '条目内容';

comment on column adi_knowledge_base_item.is_embedded is 'Deprecated.使用embedding_status代替。-- 是否已向量化,true:否,false:是';

comment on column adi_knowledge_base_item.embedding_status is '向量化状态, 1:未向量化,2:正在向量化,3:已向量化,4:失败';

comment on column adi_knowledge_base_item.embedding_status_change_time is '向量化状态变更时间';

comment on column adi_knowledge_base_item.graphical_status is '图谱化状态, 1:未图谱化,2:正在图谱化;3:已图谱化,4:失败';

comment on column adi_knowledge_base_item.graphical_status_change_time is '图谱化状态变更时间';

comment on column adi_knowledge_base_item.create_time is '创建时间';

comment on column adi_knowledge_base_item.update_time is '更新时间';

comment on column adi_knowledge_base_item.is_deleted is '0：未删除；1：已删除';

create trigger trigger_kb_item_update_time
    before update
    on adi_knowledge_base_item
    for each row
execute procedure update_modified_column();

create table adi_knowledge_base_star_record
(
    id          bigserial primary key,
    kb_id       bigint      default 0                     not null,
    kb_uuid     varchar(32) default ''::character varying not null,
    user_id     bigint      default '0'                   not null,
    user_uuid   varchar(32) default ''::character varying not null,
    create_time timestamp   default CURRENT_TIMESTAMP     not null,
    update_time timestamp   default CURRENT_TIMESTAMP     not null,
    is_deleted  boolean     default false                 not null,
    UNIQUE (kb_id, user_id)
);

comment on table adi_knowledge_base_star_record is '知识库-点赞记录';

comment on column adi_knowledge_base_star_record.kb_id is 'adi_knowledge_base id';

comment on column adi_knowledge_base_star_record.kb_uuid is 'adi_knowledge_base uuid';

comment on column adi_knowledge_base_star_record.user_id is 'adi_user id';

comment on column adi_knowledge_base_star_record.user_uuid is 'adi_user uuid';

comment on column adi_knowledge_base_star_record.create_time is '创建时间';

comment on column adi_knowledge_base_star_record.update_time is '更新时间';

comment on column adi_knowledge_base_star_record.is_deleted is '0:normal; 1:deleted';

create trigger trigger_kb_star_record_update_time
    before update
    on adi_knowledge_base_star_record
    for each row
execute procedure update_modified_column();

create table adi_knowledge_base_qa_record
(
    id              bigserial primary key,
    uuid            varchar(32)   default ''::character varying not null,
    kb_id           bigint        default 0                     not null,
    kb_uuid         varchar(32)   default ''::character varying not null,
    question        varchar(1000) default ''::character varying not null,
    prompt          text          default ''::character varying not null,
    prompt_tokens   integer       default 0                     not null,
    answer          text          default ''::character varying not null,
    answer_tokens   integer       default 0                     not null,
    source_file_ids varchar(500)  default ''::character varying not null,
    user_id         bigint        default 0                     not null,
    ai_model_id     bigint        default 0                     not null,
    create_time     timestamp     default CURRENT_TIMESTAMP     not null,
    update_time     timestamp     default CURRENT_TIMESTAMP     not null,
    is_deleted      boolean       default false                 not null
);

comment on table adi_knowledge_base_qa_record is '知识库-提问记录';

comment on column adi_knowledge_base_qa_record.kb_id is '所属知识库id';

comment on column adi_knowledge_base_qa_record.kb_uuid is '所属知识库uuid';

comment on column adi_knowledge_base_qa_record.question is '用户的原始问题';

comment on column adi_knowledge_base_qa_record.prompt is '提供给LLM的提示词';

comment on column adi_knowledge_base_qa_record.prompt_tokens is '提示词消耗的token';

comment on column adi_knowledge_base_qa_record.answer is '答案';

comment on column adi_knowledge_base_qa_record.answer_tokens is '答案消耗的token';

comment on column adi_knowledge_base_qa_record.source_file_ids is '来源文档id,以逗号隔开';

comment on column adi_knowledge_base_qa_record.user_id is '提问用户id';

comment on column adi_knowledge_base_qa_record.create_time is '创建时间';

comment on column adi_knowledge_base_qa_record.update_time is '更新时间';

comment on column adi_knowledge_base_qa_record.is_deleted is '0：未删除；1：已删除';

create trigger trigger_kb_qa_record_update_time
    before update
    on adi_knowledge_base_qa_record
    for each row
execute procedure update_modified_column();

create table adi_knowledge_base_qa_record_reference
(
    id           bigserial primary key,
    qa_record_id bigint        default 0                     not null,
    embedding_id varchar(36)   default ''::character varying not null,
    score        numeric(3, 2) default 0                     not null,
    user_id      bigint        default 0                     not null
);

comment on table adi_knowledge_base_qa_record_reference is '知识库-提问记录-向量引用列表';

comment on column adi_knowledge_base_qa_record_reference.qa_record_id is '提问记录id';

comment on column adi_knowledge_base_qa_record_reference.embedding_id is '向量uuid';

comment on column adi_knowledge_base_qa_record_reference.score is '评分';

comment on column adi_knowledge_base_qa_record_reference.user_id is '所属用户';

create trigger trigger_kb_qa_record_reference_update_time
    before update
    on adi_knowledge_base_qa_record_reference
    for each row
execute procedure update_modified_column();

-- Graph RAG
create table adi_knowledge_base_graph_segment
(
    id           bigserial primary key,
    uuid         varchar(32) default ''::character varying not null,
    kb_uuid      varchar(32) default ''::character varying not null,
    kb_item_uuid varchar(32) default ''::character varying not null,
    remark       text        default ''::character varying not null,
    user_id      bigint      default 0                     not null,
    create_time  timestamp   default CURRENT_TIMESTAMP     not null,
    update_time  timestamp   default CURRENT_TIMESTAMP     not null,
    is_deleted   boolean     default false                 not null
);

comment on table adi_knowledge_base_graph_segment is '知识库-图谱-文本块';

comment on column adi_knowledge_base_graph_segment.kb_uuid is '所属知识库uuid';

comment on column adi_knowledge_base_graph_segment.kb_item_uuid is '所属知识点uuid';

comment on column adi_knowledge_base_graph_segment.remark is '内容';

comment on column adi_knowledge_base_graph_segment.user_id is '所属用户';

create table adi_knowledge_base_qa_record_ref_graph
(
    id               bigserial primary key,
    qa_record_id     bigint default 0                     not null,
    graph_from_llm   text   default ''::character varying not null,
    graph_from_store text   default ''::character varying not null,
    user_id          bigint default 0                     not null
);

comment on table adi_knowledge_base_qa_record_ref_graph is '知识库-提问记录-图谱引用记录';

comment on column adi_knowledge_base_qa_record_ref_graph.qa_record_id is '提问记录id';

comment on column adi_knowledge_base_qa_record_ref_graph.graph_from_llm is 'LLM解析出来的图谱: vertexName1,vertexName2';

comment on column adi_knowledge_base_qa_record_ref_graph.graph_from_store is '从图数据库中查找得到的图谱: {vertices:[{id:"111",name:"vertexName1"},{id:"222",name:"vertexName2"}],edges:[{id:"333",name:"edgeName1",start:"111",end:"222"}]';

comment on column adi_knowledge_base_qa_record_ref_graph.user_id is '所属用户';

-- ai search
create table adi_ai_search_record
(
    id                     bigserial primary key,
    uuid                   varchar(32)   default ''::character varying not null,
    question               varchar(1000) default ''::character varying not null,
    search_engine_response jsonb                                       not null,
    prompt                 text          default ''::character varying not null,
    prompt_tokens          integer       default 0                     not null,
    answer                 text          default ''::character varying not null,
    answer_tokens          integer       default 0                     not null,
    user_id                bigint        default 0                     not null,
    user_uuid              varchar(32)   default ''::character varying not null,
    ai_model_id            bigint        default 0                     not null,
    create_time            timestamp     default CURRENT_TIMESTAMP     not null,
    update_time            timestamp     default CURRENT_TIMESTAMP     not null,
    is_deleted             boolean       default false                 not null
);
comment on table adi_ai_search_record is 'Search record';

comment on column adi_ai_search_record.question is 'User original question';

comment on column adi_ai_search_record.search_engine_response is 'Search engine''s response content';

comment on column adi_ai_search_record.prompt is 'Prompt of LLM';

comment on column adi_ai_search_record.prompt_tokens is 'prompt消耗的token数量';

comment on column adi_ai_search_record.answer is 'LLM response';

comment on column adi_ai_search_record.answer_tokens is 'LLM响应消耗的token数量';

comment on column adi_ai_search_record.user_id is 'Id from adi_user';

COMMENT ON COLUMN adi_ai_search_record.ai_model_id IS 'adi_ai_model id';

comment on column adi_ai_search_record.create_time is '创建时间';

comment on column adi_ai_search_record.update_time is '更新时间';

comment on column adi_ai_search_record.is_deleted is '0: Normal; 1: Deleted';

create trigger trigger_ai_search_record
    before update
    on adi_ai_search_record
    for each row
execute procedure update_modified_column();