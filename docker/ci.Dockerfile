FROM ros:humble-ros-base-jammy AS ci-base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN useradd -ms /bin/bash user
RUN apt -y install sudo && \
    echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "user:password" | chpasswd
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /home/user/.bashrc

COPY docker/etc/entrypoint_docker_ci.sh /
RUN chmod +x /entrypoint_docker_ci.sh

RUN apt -y update && \
    apt -y upgrade && \
    apt -y autoremove && \
  apt -y install pipx

USER user
WORKDIR /home/user

RUN pipx install --include-deps --force "ansible==6.*"

WORKDIR autoware
COPY ansible ./ansible
COPY ansible-galaxy-requirements.yaml .
COPY amd64.env .

RUN pipx ensurepath && ~/.local/bin/ansible-galaxy collection install -f -r ansible-galaxy-requirements.yaml

RUN source amd64.env && \
  ~/.local/bin/ansible-playbook autoware.dev_env.play_build_tools -vvv --extra-vars "" --ask-become-pass

RUN source amd64.env && \
  ~/.local/bin/ansible-playbook autoware.dev_env.play_tensorrt -vvv --extra-vars "install_devel=y cuda_version=$cuda_version cuda_install_drivers=false cudnn_version=$cudnn_version tensorrt_version=$tensorrt_version" --ask-become-pass

#RUN source amd64.env && \
#  ansible-playbook autoware.dev_env.ci_reqs -vvv --extra-vars "prompt_install_nvidia=true prompt_download_artifacts=false install_devel=true rosdistro=$rosdistro rmw_implementation=$rmw_implementation cuda_version=$cuda_version cudnn_version=$cudnn_version tensorrt_version=$tensorrt_version pre_commit_clang_format_version=$pre_commit_clang_format_version ros2_installation_type=ros-base" --ask-become-pass

USER user

ENTRYPOINT ["/entrypoint_docker_ci.sh"]
CMD ["/bin/bash"]
