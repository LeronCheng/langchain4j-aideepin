package com.moyz.adi.common.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import org.springframework.validation.annotation.Validated;

@Data
@Validated
public class ConvPresetAddReq {

    @NotBlank
    private String title;
    @NotBlank
    private String remark;
    @NotBlank
    private String aiSystemMessage;
}
